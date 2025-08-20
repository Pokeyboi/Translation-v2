# Enable Vercel Blob for this project

1. In Vercel Dashboard → your project → **Storage** → **Connect Database** → **Blob** → create a store.
2. Ensure the `BLOB_READ_WRITE_TOKEN` env var is present (Vercel adds it when you connect the store).
3. Deploy. The `/api/upload_csv` Edge Function streams CSV bodies to Blob and returns a JSON payload with a public `url`.
4. In the app, when you import a CSV, the importer will also upload the original file to Blob and show a snackbar with the Blob URL.
5. The app still stores parsed rows locally so you can use the dictionary immediately.
