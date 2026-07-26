# Deploy

Run `bash deploy/docker.sh` to build and push the image into cluster
Change the image used in the pod by new image tag
All image tagged by date like `2026-07-23_09-09`
After changing the image tag and restarting pod, may need to run migration for chatwoot db.
`sidekiq` and chatwoot `app` using same image
