FROM node:18-alpine AS base

WORKDIR /app/chatService

COPY backend/chatService/package*.json ./
RUN npm install --production

COPY . .
ENV NODE_ENV=production
EXPOSE 3004

CMD ["npm", "run", "start"]
