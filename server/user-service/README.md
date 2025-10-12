# Authentication Microservice

## Overview

The Authentication Microservice is responsible for handling user authentication and authorization within the microservices architecture. The service communicates with the API Gateway via **gRPC** and interacts with a PostgreSQL database for user management.

## Features

- **User Signup**: Register new users with a hashed password.
- **User Login**: Authenticate users with bcrypt password verification and JWT Token generation.
- **Fetch Users**: Checks that user is an **admin**. This endpoint performs cursor pagination to retrieve users from the database.
- **Update User**: Users can update their credentials and profile information.
