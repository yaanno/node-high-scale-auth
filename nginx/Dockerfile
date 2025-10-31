# Use a lightweight Nginx image
FROM nginx:alpine

# Remove the default configuration
RUN rm /etc/nginx/conf.d/default.conf

# Copy the custom configuration file into the container
COPY nginx.conf /etc/nginx/conf.d/
