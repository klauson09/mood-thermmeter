# 情緒溫度計｜Mood Thermometer

一個夢幻星空風、可和朋友共用的小型情緒日記網站。使用 React + Vite + Supabase，可部署到 Vercel / Netlify。

## 功能
- 電子郵件／密碼註冊與登入
- 建立小屋、產生 8 碼邀請碼、加入朋友的小屋
- 喜怒哀樂各自 0～100% 調整，四種情緒不必加總為 100%
- 每人每天一筆紀錄，可更新、補記過去日期
- 每筆紀錄可選擇分享或私人保存
- 小屋成員動態牆，只顯示選擇公開的紀錄
- 最近 14 天公開情緒平均圖表
- RLS 資料庫權限：使用者只能編輯自己的紀錄；同房間成員只能讀取公開紀錄

## 1. 建立 Supabase 專案
1. 到 https://supabase.com 建立免費專案。
2. 開啟專案的 **SQL Editor**。
3. 將 `supabase/schema.sql` 全部貼上並執行。
4. 到 **Project Settings → API**，複製 Project URL 與 `anon` / publishable key。
5. 到 **Authentication → Providers → Email**，確認 Email provider 已啟用。若想讓朋友註冊後立即登入，可在測試階段關閉 Confirm email；正式公開使用建議保留信箱驗證並設定 SMTP。

## 2. 本機啟動
需要 Node.js 18 或更新版本。

```bash
npm install
cp .env.example .env
```

編輯 `.env`，填入：

```env
VITE_SUPABASE_URL=https://你的專案.supabase.co
VITE_SUPABASE_ANON_KEY=你的Supabase anon或publishable key
```

再執行：

```bash
npm run dev
```

## 3. 部署成公開網址（Vercel）
1. 將整個專案資料夾推送到自己的 GitHub repository。
2. 到 https://vercel.com → Add New → Project，匯入 repository。
3. Framework 選 Vite（通常會自動偵測）。
4. 在 Environment Variables 加入 `VITE_SUPABASE_URL` 和 `VITE_SUPABASE_ANON_KEY`。
5. 按 Deploy。完成後 Vercel 會給你一個 `https://xxxxx.vercel.app` 網址，可以傳給朋友。
6. 到 Supabase → Authentication → URL Configuration，將 Site URL 設成 Vercel 網址，並把該網址加入 Redirect URLs。

## 4. 朋友如何使用
1. 打開你分享的網站網址。
2. 用自己的電子郵件註冊並登入。
3. 由其中一人建立小屋，將 8 碼邀請碼傳給其他朋友。
4. 其他人登入後輸入暱稱與邀請碼即可加入。
5. 每次紀錄時可勾選「分享這筆心情給小屋成員」；取消勾選就是私人紀錄。

## 隱私與注意事項
- 網站不會顯示密碼；登入由 Supabase Auth 處理。
- `anon` key 是前端公開金鑰，資料安全依賴 SQL 中的 Row Level Security (RLS)，不要把 `service_role` key 放進前端或 `.env`。
- 小屋邀請碼是加入憑證，請只分享給信任的人。若邀請碼外流，知道邀請碼的人可以加入該小屋。
- 每位成員只能新增、修改、刪除自己的心情紀錄。其他成員只能看到自己選擇公開的紀錄。
- 目前每個帳號只能加入一個小屋；若要換小屋，需由資料庫管理者協助更新 `profiles.room_id`。
- 目前圖表呈現最近 14 天「有公開紀錄的日子」之小屋平均值；不是個人診斷或心理評估。
- 上線前建議先用兩個測試帳號測試：建立小屋、加入、公開紀錄、私人紀錄與互相不可見的情境。

## 常見問題
**註冊後沒有登入？** 若 Supabase 開啟 Email confirmation，先到信箱點驗證連結，再回網站登入。

**朋友加入失敗？** 確認雙方都已登入、邀請碼 8 碼正確，並確認 SQL schema 已成功執行。

**要修改網站名稱或顏色？** 可從 `src/App.jsx` 與 `src/style.css` 修改。
