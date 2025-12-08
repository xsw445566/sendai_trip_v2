@echo off
color 0A
echo ==========================================
echo      正在為您重新製作 APP 並上傳...
echo      (請勿關閉視窗，這需要約 30-60 秒)
echo ==========================================

:: 1. 重新編譯網頁版 (這是讓手機變更新的關鍵)
echo [1/4] 正在編譯程式碼...
call flutter build web --base-href "/sendai_trip/" --release

:: 2. 更新 docs 資料夾 (GitHub Pages 讀取的地方)
echo [2/4] 正在更新網頁檔案...
xcopy "build\web\*" "docs\" /E /Y /Q

:: 3. 加入變更到 Git
echo [3/4] 正在加入版本控制...
git add .

:: 4. 提交並上傳 (自動填寫日期時間)
echo [4/4] 正在上傳到 GitHub...
git commit -m "Auto update %date% %time%"
git push origin main

echo.
echo ==========================================
echo      大功告成！APP 已更新完畢！
echo      請等待約 1 分鐘後，在手機重新整理網頁。
echo ==========================================
pause