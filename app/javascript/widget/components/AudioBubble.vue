<script>
export default {
  name: 'AudioBubble',
  props: {
    url: {
      type: String,
      default: '',
    },
    isUserBubble: {
      type: Boolean,
      default: false,
    },
    widgetColor: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      retryAttempt: 0,
      maxRetries: 5,
      loadError: false,
    };
  },
  computed: {
    sourceUrl() {
      if (this.retryAttempt === 0) return this.url;
      const sep = this.url.includes('?') ? '&' : '?';
      return `${this.url}${sep}_retry=${this.retryAttempt}`;
    },
  },
  watch: {
    url() {
      this.retryAttempt = 0;
      this.loadError = false;
    },
  },
  methods: {
    onAudioError() {
      if (this.retryAttempt >= this.maxRetries) {
        this.loadError = true;
        return;
      }
      const delay = 1000 * (this.retryAttempt + 1);
      setTimeout(() => {
        this.retryAttempt += 1;
      }, delay);
    },
    onCanPlay() {
      this.loadError = false;
    },
  },
};
</script>

<template>
  <div>
    <audio
      v-show="!loadError"
      ref="audioPlayer"
      controls
      preload="auto"
      class="h-10 max-w-full"
      :class="{ 'dark:invert': !isUserBubble }"
      :src="sourceUrl"
      @error="onAudioError"
      @canplay="onCanPlay"
    />
    <div v-if="loadError" class="text-xs text-n-slate-11 px-1">
      {{ $t('VOICE_RECORDER.LOAD_ERROR') }}
    </div>
  </div>
</template>
