<script setup>
import { computed } from 'vue';

const props = defineProps({
  url: { type: String, default: '' },
  readableTime: { type: String, default: '' },
});

const emit = defineEmits(['error']);

const onVideoError = () => {
  emit('error');
};

// The native media controls handle the tap inside their shadow root and
// nothing propagates out, so the chat input keeps the focus it would lose on a
// tap anywhere else in the message view, and Android WebView re-opens the soft
// keyboard for it. Media events are the only signal a control was used, so
// release the focus from there.
const releaseFocus = () => {
  document.activeElement?.blur();
};

// Android only fetches container metadata and never decodes a frame, so the
// bubble stays black until playback starts. Pointing at the very first frame
// makes it seek there, which forces that frame to be decoded and painted.
const previewUrl = computed(() =>
  props.url ? `${props.url}#t=0.001` : props.url
);
</script>

<template>
  <div class="relative block max-w-full">
    <video
      class="w-full max-w-[250px] h-auto"
      :src="previewUrl"
      controls
      preload="metadata"
      @play="releaseFocus"
      @pause="releaseFocus"
      @seeking="releaseFocus"
      @error="onVideoError"
    />
    <span
      class="absolute text-xs text-white dark:text-white right-3 bottom-1 whitespace-nowrap"
    >
      {{ readableTime }}
    </span>
  </div>
</template>
