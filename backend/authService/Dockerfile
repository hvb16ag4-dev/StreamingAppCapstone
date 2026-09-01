FROM node:18-alpine AS base

WORKDIR /app/authService

COPY backend/authService/package*.json ./
RUN npm install --production

COPY backend/authService/. ./

ENV NODE_ENV=production
EXPOSE 3001

CMD ["npm", "run", "start"]
