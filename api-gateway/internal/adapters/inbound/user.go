package inbound

import (
	"errors"
	"log"
	"net/http"
	"strconv"

	"github.com/LeonLow97/internal/adapters/inbound/dto"
	"github.com/LeonLow97/internal/config"
	"github.com/LeonLow97/internal/core/domain"
	user "github.com/LeonLow97/internal/core/services"
	"github.com/LeonLow97/internal/pkg/apierror"
	"github.com/LeonLow97/internal/pkg/contextstore"
	"github.com/LeonLow97/internal/pkg/handler"
	"github.com/LeonLow97/internal/pkg/ratelimit"
	"github.com/gin-gonic/gin"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

type UserHandler struct {
	handler.Handler
	cfg         config.Config
	rateLimiter ratelimit.RateLimiter
	UserService user.User
}

func NewUserHandler(cfg config.Config, rateLimiter ratelimit.RateLimiter, userService user.User) *UserHandler {
	return &UserHandler{
		Handler:     handler.NewHandler(),
		cfg:         cfg,
		rateLimiter: rateLimiter,
		UserService: userService,
	}
}

func (h *UserHandler) Login(c *gin.Context) {
	// Deserialize request body and validate request fields
	var req dto.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		apierror.ErrBadRequest.APIError(c, err)
		return
	}
	if err := h.ValidateStruct(req); err != nil {
		apierror.ErrBadRequest.APIError(c, err)
		return
	}

	clientIP := c.ClientIP()

	// Rate limiting login endpoint
	if err := h.rateLimiter.LoginRateLimiter(c, req.Email, clientIP); err != nil {
		switch {
		case errors.Is(err, ratelimit.ErrLoginBurstRateLimitExceeded):
			apierror.ErrTooManyRequests.APIError(c, err)
			return
		case errors.Is(err, ratelimit.ErrLoginFailRateLimitExceeded):
			apierror.ErrTooManyRequests.APIError(c, err)
			return
		default:
			// don't block login on unexpected rate limiter errors
			log.Printf("unexpected rate limiter error: %v\n", err)
		}
	}

	resp, token, err := h.UserService.Login(c, dto.FromLoginRequest(&req))
	if err != nil {
		code := h.Handler.RespondGrpcError(c, err)

		// Increment fail counter only if unauthenticated
		if code == codes.Unauthenticated {
			if err := h.rateLimiter.IncrementLoginFailRateLimiter(c, req.Email, clientIP); err != nil {
				log.Printf("warning: failed to increment login fail counter: %v", err)
			}
		}

		return
	}

	if err := h.rateLimiter.ResetLoginFailRateLimiter(c, req.Email, c.ClientIP()); err != nil {
		log.Printf("warning: failed to reset login fail counter: %v", err)
	}

	http.SetCookie(c.Writer, &http.Cookie{
		Name:     h.cfg.AuthJWTToken.Name,
		Value:    token,
		MaxAge:   h.cfg.AuthJWTToken.MaxAge,
		Path:     h.cfg.AuthJWTToken.Path,
		Domain:   h.cfg.AuthJWTToken.Domain,
		Secure:   h.cfg.AuthJWTToken.Secure,
		HttpOnly: h.cfg.AuthJWTToken.HTTPOnly,
	})
	c.JSON(http.StatusOK, dto.ToLoginResponse(resp))
}

func (h *UserHandler) SignUp() gin.HandlerFunc {
	return func(c *gin.Context) {
		var req dto.SignUpRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apierror.ErrBadRequest.APIError(c, err)
			return
		}

		if err := h.ValidateStruct(req); err != nil {
			apierror.ErrBadRequest.APIError(c, err)
			return
		}

		user := domain.User{
			FirstName: req.FirstName,
			LastName:  req.LastName,
			Password:  req.Password,
			Email:     req.Email,
		}

		if err := h.UserService.SignUp(c, user); err != nil {
			status, ok := status.FromError(err)
			if !ok {
				apierror.ErrInternalServerError.APIError(c, err)
				return
			}

			var customErr *apierror.CustomError
			switch status.Code() {
			case codes.InvalidArgument:
				customErr = apierror.ErrBadRequest
			case codes.AlreadyExists:
				customErr = apierror.ErrEmailAlreadyExists
			default:
				customErr = apierror.ErrInternalServerError
			}
			customErr.APIError(c, err)
			return
		}

		h.ResponseNoContent(c, http.StatusCreated)
	}
}

func (h *UserHandler) Logout() gin.HandlerFunc {
	return func(c *gin.Context) {
		cookie, err := c.Request.Cookie(h.cfg.AuthJWTToken.Name)
		if err != nil {
			switch {
			case errors.Is(err, http.ErrNoCookie):
				log.Printf("No %s cookie found\n", h.cfg.AuthJWTToken.Name)
			default:
				log.Printf("failed to logout with error: %v\n", err)
			}
			h.ResponseNoContent(c, http.StatusOK)
			return
		}

		cookie.MaxAge = -1               // Invalidate the existing cookie by setting MaxAge to -1
		http.SetCookie(c.Writer, cookie) // Update the cookie in the response header to invalidate it
		h.ResponseNoContent(c, http.StatusOK)
	}
}

func (h *UserHandler) GetUsers() gin.HandlerFunc {
	return func(c *gin.Context) {
		limitStr := h.GetQueryParam(c, "limit", "10")
		limit, err := strconv.Atoi(limitStr)
		if err != nil {
			apierror.ErrBadRequest.APIError(c, err)
			return
		}
		cursor := h.GetQueryParam(c, "cursor", "")

		md, err := contextstore.GRPCMetadataFromContext(c)
		if err != nil {
			apierror.ErrInternalServerError.APIError(c, err)
			return
		}
		grpcCtx := metadata.NewOutgoingContext(c, md)

		domainResp, nextCursor, err := h.UserService.GetUsers(grpcCtx, int64(limit), cursor)
		if err != nil {
			status, ok := status.FromError(err)
			if !ok {
				apierror.ErrInternalServerError.APIError(c, err)
				return
			}

			var customErr *apierror.CustomError
			switch status.Code() {
			case codes.Unauthenticated:
				customErr = apierror.ErrUnauthorized
			default:
				customErr = apierror.ErrInternalServerError
			}
			customErr.APIError(c, err)
			return
		}

		resp := &dto.GetUsersResponse{
			Users:      make([]dto.User, len(domainResp)),
			NextCursor: nextCursor,
		}
		for i, user := range domainResp {
			resp.Users[i] = dto.User{
				ID:        user.ID,
				FirstName: user.FirstName,
				LastName:  user.LastName,
				Email:     user.Email,
				Active:    user.Active,
				Admin:     user.Admin,
			}
		}

		h.ResponseJSON(c, http.StatusOK, resp)
	}
}

func (h *UserHandler) UpdateUser() gin.HandlerFunc {
	return func(c *gin.Context) {
		md, err := contextstore.GRPCMetadataFromContext(c)
		if err != nil {
			apierror.ErrInternalServerError.APIError(c, err)
			return
		}
		grpcCtx := metadata.NewOutgoingContext(c, md)

		var req dto.UpdateUserRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			apierror.ErrBadRequest.APIError(c, nil)
			return
		}

		if err := h.ValidateStruct(req); err != nil {
			apierror.ErrBadRequest.APIError(c, err)
			return
		}

		user := domain.User{
			Password:  req.Password,
			FirstName: req.FirstName,
			LastName:  req.LastName,
			Email:     req.Email,
		}

		if err := h.UserService.UpdateUser(grpcCtx, user); err != nil {
			if status, ok := status.FromError(err); ok {
				errorCode := status.Code()
				switch int32(errorCode) {
				case 5:
					apierror.ErrBadRequest.APIError(c, nil)
				default:
					apierror.ErrInternalServerError.APIError(c, nil)
				}
				return
			}
		}

		h.ResponseNoContent(c, http.StatusNoContent)
	}
}
