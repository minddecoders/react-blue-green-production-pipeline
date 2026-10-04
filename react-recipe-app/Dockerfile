# === STAGE 1: COMPILING VITE REACT SOURCE CODE ===
FROM node:20-alpine AS build_stage
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# === STAGE 2: HIGH-PERFORMANCE NGINX SERVING INTERFACE ===
FROM nginx:stable-alpine
# 🔄 VITE OPTIMIZED: Copies from the dynamic 'dist' asset folder instead of legacy 'build'!
COPY --from=build_stage /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
