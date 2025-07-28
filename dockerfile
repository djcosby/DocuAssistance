# Dockerfile for a Node.js application with a separate server and frontend.
# This uses a multi-stage build to create a lean final image.

#--------------------------------------------------------------------------------
# Stage 1: Builder
# This stage installs all dependencies for both the server and the frontend,
# and then builds the frontend assets. It's a temporary environment that will
# be discarded after the build is complete.
#--------------------------------------------------------------------------------
FROM node:22 AS builder

# Set the working directory inside the container. All subsequent commands
# will run from this path.
WORKDIR /app

# Copy all project files from your local machine into the container's /app directory.
# This includes the server, frontend, package.json files, etc.
COPY . ./

# Create placeholder .env files.
# NOTE: This is good for building, but for production, it's much safer to
# inject environment variables at runtime instead of writing them to a file.
RUN echo "API_KEY=PLACEHOLDER" > ./.env
RUN echo "GEMINI_API_KEY=PLACEHOLDER" >> ./.env

# --- Install Server Dependencies ---
# Move into the server directory.
WORKDIR /app/server
# Run npm install to fetch only the server's dependencies as defined
# in /server/package.json.
RUN npm install

# --- Install Frontend Dependencies & Build ---
# Move back to the root application directory.
WORKDIR /app
# Create the 'dist' directory where the build output will be placed.
# This prevents errors if the build process doesn't create it automatically.
RUN mkdir dist
# This command checks if a package.json exists in the root. If it does,
# it runs 'npm install' to get the frontend dependencies and then 'npm run build'
# to compile the frontend code into static assets, placing them in the 'dist' folder.
RUN bash -c 'if [ -f package.json ]; then npm install && npm run build; fi'


#--------------------------------------------------------------------------------
# Stage 2: Final Production Image
# This stage creates the final, lightweight image that will be deployed.
# It does NOT include all the development dependencies or source files from
# the builder stage, only the necessary compiled code and node_modules.
#--------------------------------------------------------------------------------
FROM node:22

# Set the working directory for the final image.
WORKDIR /app

# Copy only the necessary server files from the 'builder' stage.
# This includes the server code and its specific node_modules.
COPY --from=builder /app/server .

# Copy the compiled frontend assets from the 'builder' stage into a 'dist'
# folder in our final image. The server will likely be configured to serve
# static files from this directory.
COPY --from=builder /app/dist ./dist

# Inform Docker that the container will listen on port 3000 at runtime.
# This is documentation; you still need to map the port when running the container.
EXPOSE 3000

# The command that will be executed when the container starts.
# This runs your Node.js server.
CMD ["node", "server.js"]