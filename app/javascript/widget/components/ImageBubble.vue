<script>
import { getContrastingTextColor } from '@chatwoot/utils';

export default {
  props: {
    url: { type: String, default: '' },
    thumb: { type: String, default: '' },
    readableTime: { type: String, default: '' },
    widgetColor: { type: String, default: '' },
    isUserBubble: { type: Boolean, default: false },
  },
  emits: ['error', 'openGallery'],
  computed: {
    contrastingTextColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    textColor() {
      return this.isUserBubble && this.widgetColor
        ? this.contrastingTextColor
        : '';
    },
  },
  methods: {
    onImgError() {
      this.$emit('error');
    },
    onOpenGallery() {
      this.$emit('openGallery', this.url);
    },
  },
};
</script>

<template>
  <div class="image">
    <div class="preview">
      <a
        :href="url"
        target="_blank"
        rel="noreferrer noopener nofollow"
        class="wrap"
        @click.prevent="onOpenGallery"
      >
        <img :src="thumb" alt="Picture message" @error="onImgError" />
        <span class="time">{{ readableTime }}</span>
      </a>
      <button
        class="absolute z-10 flex items-center justify-center w-6 h-6 rounded-full bg-white/70 text-n-slate-11 hover:bg-white/90 transition-colors ltr:right-1 rtl:left-1 bottom-1 shadow-sm"
        :title="$t('IMAGE_GALLERY.FULLSCREEN')"
        @click.stop="onOpenGallery"
      >
        <i class="i-lucide-maximize size-3" />
      </button>
    </div>
    <div class="leading-none mt-1 ltr:pl-1 rtl:pr-1">
      <a
        class="download"
        rel="noreferrer noopener nofollow"
        target="_blank"
        :style="{ color: textColor }"
        :href="url"
      >
        {{ $t('COMPONENTS.FILE_BUBBLE.DOWNLOAD') }}
      </a>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.image {
  display: block;

  .preview {
    position: relative;
  }

  .wrap {
    position: relative;
    display: flex;
    max-width: 100%;

    &::before {
      background-image: linear-gradient(-180deg, transparent 3%, #1f2d3d 130%);
      bottom: 0;
      content: '';
      height: 20%;
      left: 0;
      opacity: 0.8;
      position: absolute;
      width: 100%;
    }
  }

  img {
    width: 100%;
    max-width: 250px;
  }

  .time {
    @apply text-xs bottom-1 text-white ltr:left-3 rtl:right-3 whitespace-nowrap absolute;
  }

  .download {
    @apply text-n-brand font-medium p-0 m-0 text-xs no-underline;
  }
}
</style>
