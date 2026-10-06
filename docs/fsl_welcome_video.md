# FSL welcome video for the website

A short welcome for Deaf and hard-of-hearing visitors, signed in Filipino Sign
Language by a Deaf or fluent FSL signer. The website shows it in its own
section near the top of the home page — but only once the file exists, so
nothing appears until a real recording is ready. Please do not use a stitched
sequence of dictionary clips or a hearing person's approximation: a Deaf
visitor will notice, and the point of the video is to greet them properly.

**Published 7 October 2026** with the group's own recording (52 seconds,
`GROUP_2_THESIS_FOREVER - WEBSITE`, kept on Cloudinary as the original). The
website copy is `website/assets/videos/fsl-welcome.mp4` (480p, silent — the
original's sound track is only room noise) with the poster
`fsl-welcome-poster.webp`. To replace it, follow "Export and publish" below.

## What to sign (about 30–40 seconds)

Sign the meaning in natural FSL — this is a guide, not a word-for-word script.

**English**
> Hello, and welcome! This is FlashLearn PWD, a free learning app for
> children with disabilities. It teaches everyday words in English, Filipino
> and Filipino Sign Language, with games, stories and a sign dictionary you
> can watch on this website. There are no ads and no account. To get the app,
> press the Download button, then follow the steps. Thank you, and enjoy
> learning!

**Filipino**
> Kumusta, at maligayang pagdating! Ito ang FlashLearn PWD, isang libreng app
> sa pag-aaral para sa mga batang may kapansanan. Nagtuturo ito ng mga
> pang-araw-araw na salita sa English, Filipino at Filipino Sign Language, may
> mga laro, kuwento at diksyunaryo ng senyas na mapapanood sa website na ito.
> Walang ads at walang account. Para makuha ang app, pindutin ang Download,
> at sundin ang mga hakbang. Salamat, at masayang pag-aaral!

## Filming

- Plain, light background; even light on the face and hands; no strong
  shadows. The dictionary clips (same signer, same backdrop) are a good match.
- Frame from the top of the head to the waist, with room for signs at the
  sides. Landscape (16:9) fits the page best.
- Phone on a stand, at chest height. Record in 1080p; the recipe below
  shrinks it.

## Export and publish

1. Shrink it the same way as the website's sign clips (480p, BT.709, no
   sound, web-ready):

   ```
   C:\ffmpeg\bin\ffmpeg.exe -i raw.mp4 -vf "scale=-2:480,fps=30" -c:v libx264 -profile:v main -crf 30 -preset slow -an -movflags +faststart -pix_fmt yuv420p website\assets\videos\fsl-welcome.mp4
   ```

   If the phone recorded HDR (colours look washed out), use the tone-mapping
   recipe in `tools/README.md` instead.

2. Make a poster from a calm opening frame (it shows before the video
   plays):

   ```
   C:\ffmpeg\bin\ffmpeg.exe -ss 0.6 -i raw.mp4 -frames:v 1 -vf "scale=854:480" poster.png
   ```

   then save `poster.png` as `website/assets/videos/fsl-welcome-poster.webp`.

3. No captions, on purpose: a browser draws captions over the bottom of the
   picture, which is where the signer's hands are. Hearing parents read the
   same message in the "Read the welcome" panel under the video instead. Its
   English and Filipino text is `WELCOME_WORDS_EN` / `WELCOME_WORDS_FIL` in
   `tools/release_page_build.py` — it follows the guide above, so if a
   recording says something different, change the text there to match.

4. Run `python tools/release_page_build.py`. It adds the welcome section to
   `website/index.html` and bumps the offline cache. Check the page locally,
   commit, and deploy as usual.
