FROM node:18-alpine AS base

WORKDIR /app

COPY package*.json ./
RUN apk add --no-cache python3 make g++ libstdc++ \
    && npm install --production \
    && apk del python3 make g++

COPY . .

ENV NODE_ENV=production
EXPOSE 3001

CMD ["npm", "run", "start"]
