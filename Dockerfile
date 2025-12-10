# 使用官方 Flutter 映像檔來建置 Web 應用程式
FROM ghcr.io/cirruslabs/flutter:stable AS build

# 設定工作目錄
WORKDIR /app

# 複製專案檔案到容器
COPY . .

# 啟用 web 支援
RUN flutter config --enable-web

# 下載 dependencies
RUN flutter pub get

# 建置 Flutter Web release
RUN flutter build web --release

# ---------------------------------------------
# 第二階段：使用 nginx 伺服器託管 Flutter Web
# ---------------------------------------------
FROM nginx:alpine

# 刪除預設 nginx 靜態頁面
RUN rm -rf /usr/share/nginx/html/*

# 複製 Flutter Web build 輸出到 nginx 靜態目錄
COPY --from=build /app/build/web /usr/share/nginx/html

# 開 port
EXPOSE 80

# 啟動 nginx
CMD ["nginx", "-g", "daemon off;"]
