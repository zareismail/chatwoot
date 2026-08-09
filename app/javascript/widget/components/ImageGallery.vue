<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';

const props = defineProps({
  images: { type: Array, default: () => [] },
  startIndex: { type: Number, default: 0 },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });

const activeIndex = ref(props.startIndex);
const rotation = ref(0);

watch(
  () => props.startIndex,
  val => {
    activeIndex.value = val;
    rotation.value = 0;
  }
);

const dragX = ref(0);
const isDragging = ref(false);
let touchStartX = 0;

const SWIPE_THRESHOLD = 60;

const currentImage = computed(() => props.images[activeIndex.value] || null);
const hasMultiple = computed(() => props.images.length > 1);
const hasPrev = computed(() => activeIndex.value > 0);
const hasNext = computed(() => activeIndex.value < props.images.length - 1);

const goToPrev = () => {
  if (hasPrev.value) {
    activeIndex.value -= 1;
    rotation.value = 0;
  }
};

const goToNext = () => {
  if (hasNext.value) {
    activeIndex.value += 1;
    rotation.value = 0;
  }
};

const rotateCW = () => {
  rotation.value = (rotation.value + 90) % 360;
};

const rotateCCW = () => {
  rotation.value = (rotation.value - 90 + 360) % 360;
};

const onClose = () => {
  show.value = false;
  rotation.value = 0;
  emit('close');
};

const onTouchStart = e => {
  if (!hasMultiple.value || e.touches.length !== 1) return;
  touchStartX = e.touches[0].clientX;
  isDragging.value = true;
};

const onTouchMove = e => {
  if (!isDragging.value) return;
  dragX.value = e.touches[0].clientX - touchStartX;
};

const onTouchEnd = () => {
  if (!isDragging.value) return;
  isDragging.value = false;
  if (dragX.value <= -SWIPE_THRESHOLD) {
    goToNext();
  } else if (dragX.value >= SWIPE_THRESHOLD) {
    goToPrev();
  }
  dragX.value = 0;
};

// The Android host asks the page whether it wants the back press before it
// closes the chat, so the gallery can consume it and stay in the conversation.
const handleHostBack = () => {
  if (!show.value) return false;
  onClose();
  return true;
};

const onDownload = () => {
  if (!currentImage.value) return;
  const url = currentImage.value.data_url;
  const a = document.createElement('a');
  a.href = url;
  a.target = '_blank';
  a.download = url.split('/').pop() || 'image';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
};

const handleKeydown = e => {
  if (!show.value) return;
  if (e.key === 'Escape') onClose();
  if (e.key === 'ArrowLeft') goToPrev();
  if (e.key === 'ArrowRight') goToNext();
};

onMounted(() => {
  window.addEventListener('keydown', handleKeydown);
  window.chatwootHandleHostBack = handleHostBack;
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeydown);
  delete window.chatwootHandleHostBack;
});
</script>

<template>
    <div
      v-if="show && currentImage"
      class="fixed inset-0 z-[9999] flex flex-col bg-white select-none"
    >
      <header class="flex items-center justify-end gap-1 px-4 py-2.5 shrink-0 border-b border-n-weak bg-white">
        <button
          :title="$t('IMAGE_GALLERY.ROTATE_COUNTER_CLOCKWISE')"
          class="flex items-center justify-center w-8 h-8 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors"
          @click.stop="rotateCCW"
        >
          <i class="i-lucide-rotate-ccw size-4.5" />
        </button>
        <button
          :title="$t('IMAGE_GALLERY.ROTATE_CLOCKWISE')"
          class="flex items-center justify-center w-8 h-8 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors"
          @click.stop="rotateCW"
        >
          <i class="i-lucide-rotate-cw size-4.5" />
        </button>
        <button
          :title="$t('IMAGE_GALLERY.DOWNLOAD')"
          class="flex items-center justify-center w-8 h-8 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors"
          @click.stop="onDownload"
        >
          <i class="i-lucide-download size-4.5" />
        </button>
        <button
          :title="$t('IMAGE_GALLERY.CLOSE')"
          class="flex items-center justify-center w-8 h-8 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors"
          @click.stop="onClose"
        >
          <i class="i-lucide-x size-5" />
        </button>
      </header>

    <div
      class="flex flex-1 items-center justify-center overflow-hidden p-4 touch-none"
      @touchstart="onTouchStart"
      @touchmove="onTouchMove"
      @touchend="onTouchEnd"
      @touchcancel="onTouchEnd"
    >
      <img
        :key="currentImage.data_url"
        :src="currentImage.data_url"
        class="max-h-full max-w-full object-contain"
        :class="{
          'transition-transform duration-200 ease-in-out': !isDragging,
        }"
        :style="{
          transform: `translateX(${dragX}px) rotate(${rotation}deg)`,
        }"
        alt=""
        @click.stop
      />
    </div>

    <footer
      v-if="hasMultiple"
      class="flex items-center justify-center gap-3 px-4 py-3 shrink-0 border-t border-n-weak bg-white"
    >
      <button
        :title="$t('IMAGE_GALLERY.PREVIOUS')"
        class="flex items-center justify-center w-9 h-9 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
        :disabled="!hasPrev"
        @click.stop="goToPrev"
      >
        <i class="ltr:i-lucide-chevron-left rtl:i-lucide-chevron-right size-5" />
      </button>
      <span class="text-sm text-n-slate-11 min-w-[3rem] text-center tabular-nums">
        {{ activeIndex + 1 }} / {{ images.length }}
      </span>
      <button
        :title="$t('IMAGE_GALLERY.NEXT')"
        class="flex items-center justify-center w-9 h-9 rounded text-n-slate-11 hover:bg-n-slate-3 transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
        :disabled="!hasNext"
        @click.stop="goToNext"
      >
        <i class="ltr:i-lucide-chevron-right rtl:i-lucide-chevron-left size-5" />
      </button>
    </footer>
  </div>
</template>
