<script>
export default {
  props: {
    url: { type: String, default: '' },
    thumb: { type: String, default: '' },
    readableTime: { type: String, default: '' },
  },
  emits: ['error', 'openGallery'],
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
    <a
      :href="url"
      target="_blank"
      rel="noreferrer noopener nofollow"
      class="wrap"
    >
      <img :src="thumb" alt="Picture message" @error="onImgError" />
      <span class="time">{{ readableTime }}</span>
    </a>
    <button
      class="absolute z-10 flex items-center justify-center w-6 h-6 rounded-full bg-white/70 text-n-slate-11 hover:bg-white/90 transition-colors ltr:right-1 rtl:left-1 top-1 shadow-sm"
      :title="$t('IMAGE_GALLERY.FULLSCREEN')"
      @click.stop="onOpenGallery"
    >
      <i class="i-lucide-maximize size-3" />
    </button>
  </div>
</template>

<style lang="scss" scoped>
.image {
  display: block;
  position: relative;

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
    @apply text-xs bottom-1 text-white ltr:right-3 rtl:left-3 whitespace-nowrap absolute;
  }
}
</style>
