FROM node:18-alpine AS base

WORKDIR /app/adminService

COPY ./backend/adminService/package*.json ./
RUN npm install --production

COPY ./backend/adminService/. ./
ENV NODE_ENV=production
EXPOSE 3003

CMD ["npm", "run", "start"]
