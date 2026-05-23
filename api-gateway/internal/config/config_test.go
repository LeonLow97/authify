package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/spf13/viper"
	"github.com/stretchr/testify/assert"
)

// writeTempConfig creates a config file in baseDir/config/<mode>.yaml
func writeTempConfig(t *testing.T, baseDir, mode, yaml string) {
	t.Helper()
	cfgDir := filepath.Join(baseDir, "config")
	assert.NoError(t, os.MkdirAll(cfgDir, 0755))
	file := filepath.Join(cfgDir, mode+".yaml")
	assert.NoError(t, os.WriteFile(file, []byte(yaml), 0644))
}

func writeTempRateLimitConfig(t *testing.T, baseDir string) {
	t.Helper()
	cfgDir := filepath.Join(baseDir, "config")
	assert.NoError(t, os.MkdirAll(cfgDir, 0755))
	file := filepath.Join(cfgDir, "ratelimit.yaml")
	assert.NoError(t, os.WriteFile(file, []byte("auth: {}\n"), 0644))
}

// withWorkingDir changes to a temporary working directory for the duration of the test.
// It automatically restores the original directory afterward.
func withWorkingDir(t *testing.T, f func(tempDir string)) {
	orig, err := os.Getwd()
	assert.NoError(t, err)
	t.Cleanup(func() { _ = os.Chdir(orig) })

	tempDir := t.TempDir()
	assert.NoError(t, os.Chdir(tempDir))
	f(tempDir)
}

// withEnv sets an environment variable for the duration of the test.
// If value is empty, it unsets the variable.
func withEnv(t *testing.T, key, value string) {
	if value == "" {
		os.Unsetenv(key)
	} else {
		assert.NoError(t, os.Setenv(key, value))
	}
	t.Cleanup(func() { _ = os.Unsetenv(key) })
}

func Test_LoadConfig(t *testing.T) {
	const validYAML = `
mode: development
server:
  base_url: "127.0.0.1"
  port: 8080
`

	t.Run("development mode", func(t *testing.T) {
		t.Run("config file exists", func(t *testing.T) {
			withWorkingDir(t, func(tempDir string) {
				writeTempConfig(t, tempDir, ModeDevelopment, validYAML)
				writeTempRateLimitConfig(t, tempDir)
				withEnv(t, "MODE", ModeDevelopment)
				cfg, err := LoadConfig()
				assert.NoError(t, err)
				assert.NotNil(t, cfg)
				assert.Equal(t, ModeDevelopment, cfg.Mode)
			})
		})

		t.Run("config file does not exist", func(t *testing.T) {
			withWorkingDir(t, func(_ string) {
				withEnv(t, "MODE", ModeDevelopment)
				cfg, err := LoadConfig()
				assert.Error(t, err)
				assert.Nil(t, cfg)
			})
		})

		t.Run("Mode env var not set, defaults to development", func(t *testing.T) {
			withWorkingDir(t, func(tempDir string) {
				writeTempConfig(t, tempDir, ModeDevelopment, validYAML)
				writeTempRateLimitConfig(t, tempDir)
				withEnv(t, "MODE", "") // unset
				cfg, err := LoadConfig()
				assert.NoError(t, err)
				assert.NotNil(t, cfg)
				assert.Equal(t, ModeDevelopment, cfg.Mode)
			})
		})

		t.Run("unknown Mode env var", func(t *testing.T) {
			withWorkingDir(t, func(_ string) {
				withEnv(t, "MODE", "unknown")
				cfg, err := LoadConfig()
				assert.Error(t, err)
				assert.Nil(t, cfg)
			})
		})
	})
}

func Test_LoadConfig_EnvOverridesNestedValues(t *testing.T) {
	const productionYAML = `
mode: production
server:
  base_url: "0.0.0.0"
  port: 80
user_service:
  base_url: "0.0.0.0"
  port: 50051
auth_jwt_token:
  name: authify-token
  max_age: 3600
  secure: false
  http_only: true
  path: /
  secret: CHANGE_ME
  domain: CHANGE_ME
redis:
  port: 6379
  database_index: 0
  address: CHANGE_ME
  password: CHANGE_ME
`

	withWorkingDir(t, func(tempDir string) {
		writeTempConfig(t, tempDir, ModeProduction, productionYAML)
		writeTempRateLimitConfig(t, tempDir)
		withEnv(t, "MODE", ModeProduction)
		withEnv(t, "SERVER_PORT", "8080")
		withEnv(t, "USER_SERVICE_BASE_URL", "10.0.3.10")
		withEnv(t, "REDIS_ADDRESS", "authify-redis.internal")
		withEnv(t, "AUTH_JWT_TOKEN_DOMAIN", "localhost")

		cfg, err := LoadConfig()
		assert.NoError(t, err)
		assert.NotNil(t, cfg)
		assert.Equal(t, 8080, cfg.Server.Port)
		assert.Equal(t, "10.0.3.10", cfg.UserService.BaseUrl)
		assert.Equal(t, "authify-redis.internal", cfg.RedisConfig.Address)
		assert.Equal(t, "localhost", cfg.AuthJWTToken.Domain)
	})
}

func Test_setDefaultValues(t *testing.T) {
	var cfg Config
	vpr := viper.New()

	cfg.setDefaultValues(vpr)
	assert.Equal(t, "localhost", vpr.GetString("server.url"))
	assert.Equal(t, 80, vpr.GetInt("server.port"))
}
