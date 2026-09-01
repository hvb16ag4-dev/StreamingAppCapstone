FROM node:18-alpine AS base

WORKDIR /app/streamingService

COPY backend/streamingService/package*.json ./
RUN npm install --production

COPY backend/streamingService/. ./
ENV NODE_ENV=production
EXPOSE 3002

CMD ["npm", "run", "start"]
