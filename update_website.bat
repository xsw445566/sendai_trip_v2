@echo off
echo ===============================
echo  1. 正在重新製作網頁版 APP...
echo ===============================
call flutter build web --base-href "/sendai_trip/" --release

echo.
echo ===============================
echo  2. 正在更新 docs 資料夾...
echo ===============================
xcopy "build\web\*" "docs\" /E /Y

echo.
echo ===============================
echo  3. 正在上傳到 GitHub...
echo ===============================
git add .
git commit -m "Update Web App %date% %time%"
git push origin main

echo.
echo ===========================================
echo  大功告成！請等待 1-2 分鐘後重新整理手機網頁
echo ===========================================
pause