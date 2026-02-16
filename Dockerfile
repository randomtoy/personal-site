FROM node:20-alpine AS css-builder
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci
COPY assets/ assets/
COPY layouts/ layouts/
COPY data/ data/
COPY content/ content/
RUN npx @tailwindcss/cli -i ./assets/css/main.css -o ./assets/css/compiled.css --minify

FROM hugomods/hugo:exts AS hugo-builder
WORKDIR /src
COPY . .
COPY --from=css-builder /src/assets/css/compiled.css assets/css/compiled.css
RUN hugo --minify

FROM nginx:1.27-alpine
COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=hugo-builder /src/public /usr/share/nginx/html
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html
EXPOSE 80
USER nginx
