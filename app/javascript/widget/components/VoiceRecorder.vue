<script>
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import Spinner from 'shared/components/Spinner.vue';
import { DirectUpload } from 'activestorage';
import { mapGetters } from 'vuex';

export default {
  name: 'VoiceRecorder',
  components: {
    FluentIcon,
    Spinner,
  },
  props: {
    onSendAttachment: {
      type: Function,
      default: () => {},
    },
    canShowMic: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['recording-state-changed'],
  data() {
    return {
      recordingState: 'idle', // 'idle' | 'recording' | 'denied' | 'error'
      mediaRecorder: null,
      recordedChunks: [],
      recordingTimer: 0,
      timerInterval: null,
      errorMessage: '',
      stream: null,
      isSupported: true,
      isUploading: false,
    };
  },
  computed: {
    ...mapGetters({
      globalConfig: 'globalConfig/get',
    }),
    formattedTime() {
      const min = Math.floor(this.recordingTimer / 60);
      const sec = this.recordingTimer % 60;
      return `${String(min).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
    },
    isIdle() {
      return this.recordingState === 'idle';
    },
    isRecording() {
      return this.recordingState === 'recording';
    },
    isError() {
      return (
        this.recordingState === 'denied' || this.recordingState === 'error'
      );
    },
  },
  mounted() {
    console.log('[VoiceRecorder] mounted, MediaRecorder:', typeof MediaRecorder !== 'undefined', 'mediaDevices.getUserMedia:', !!(navigator.mediaDevices?.getUserMedia));
    if (typeof MediaRecorder === 'undefined') {
      this.isSupported = false;
    }
  },
  beforeUnmount() {
    this.cleanup();
  },
  methods: {
    determineMimeType() {
      const types = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/mp4',
        'audio/ogg;codecs=opus',
      ];
      return types.find(type => MediaRecorder.isTypeSupported(type)) || '';
    },
    async startRecording() {
      console.log('[VoiceRecorder] startRecording called, state:', this.recordingState);
      if (this.recordingState !== 'idle') return;

      if (!navigator.mediaDevices?.getUserMedia) {
        console.error('[VoiceRecorder] navigator.mediaDevices.getUserMedia not available (requires HTTPS or localhost)');
        this.errorMessage = this.$t('VOICE_RECORDER.UNSUPPORTED');
        this.recordingState = 'error';
        this.$emit('recording-state-changed', false);
        return;
      }

      try {
        this.recordedChunks = [];
        this.recordingTimer = 0;
        this.errorMessage = '';

        const mimeType = this.determineMimeType();
        console.log('[VoiceRecorder] mimeType:', mimeType);
        console.log('[VoiceRecorder] calling getUserMedia...');

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        console.log('[VoiceRecorder] getUserMedia succeeded, tracks:', stream.getAudioTracks().length);
        this.stream = stream;

        const options = mimeType ? { mimeType } : {};
        this.mediaRecorder = new MediaRecorder(stream, options);
        this.mediaRecorder.ondataavailable = this.handleDataAvailable;
        this.mediaRecorder.onstop = this.handleRecordingStop;
        this.mediaRecorder.onerror = (e) => {
          console.error('[VoiceRecorder] MediaRecorder error:', e);
          this.errorMessage = this.$t('VOICE_RECORDER.ERROR');
          this.recordingState = 'denied';
          this.$emit('recording-state-changed', false);
          this.cleanup();
        };

        this.mediaRecorder.start();
        console.log('[VoiceRecorder] recording started');
        this.recordingState = 'recording';
        this.$emit('recording-state-changed', true);
        this.startTimer();
      } catch (err) {
        console.error('[VoiceRecorder] error:', err.name, err.message);
        if (
          err.name === 'NotAllowedError' ||
          err.name === 'PermissionDeniedError'
        ) {
          this.errorMessage = this.$t('VOICE_RECORDER.PERMISSION_DENIED');
          this.recordingState = 'denied';
        } else {
          this.errorMessage = this.$t('VOICE_RECORDER.ERROR') || err.message;
          this.recordingState = 'error';
        }
        this.$emit('recording-state-changed', false);
      }
    },
    stopRecording() {
      if (this.recordingState !== 'recording' || !this.mediaRecorder) return;

      if (this.mediaRecorder.state === 'recording') {
        this.mediaRecorder.stop();
      }
    },
    cancelRecording() {
      if (this.recordingState !== 'recording' || !this.mediaRecorder) return;

      this.stopTimer();
      this.mediaRecorder.onstop = null;
      if (this.mediaRecorder.state === 'recording') {
        this.mediaRecorder.stop();
      }
      this.cleanup();
      this.recordingState = 'idle';
      this.$emit('recording-state-changed', false);
    },
    resetRecording() {
      this.cleanup();
      this.recordingState = 'idle';
      this.errorMessage = '';
      this.$emit('recording-state-changed', false);
    },
    handleDataAvailable(event) {
      if (event.data && event.data.size > 0) {
        this.recordedChunks.push(event.data);
      }
    },
    handleRecordingStop() {
      this.stopTimer();

      const blob = new Blob(this.recordedChunks, {
        type: this.mediaRecorder.mimeType,
      });

      if (blob.size < 100) {
        this.cleanup();
        this.recordingState = 'idle';
        this.$emit('recording-state-changed', false);
        return;
      }

      const mimeType = this.mediaRecorder.mimeType || 'audio/webm';
      const extension = mimeType.includes('mp4') ? 'm4a' : 'webm';
      const file = new File([blob], `voice-message-${Date.now()}.${extension}`, {
        type: mimeType,
      });

      const thumbUrl = URL.createObjectURL(blob);

      this.cleanup();
      this.recordingState = 'idle';
      this.$emit('recording-state-changed', false);

      if (this.globalConfig.directUploadsEnabled) {
        this.uploadViaDirectUpload(file, thumbUrl);
      } else {
        this.onSendAttachment({
          file: file,
          thumbUrl: thumbUrl,
          fileType: 'audio',
        });
      }
    },
    uploadViaDirectUpload(file, thumbUrl) {
      this.isUploading = true;
      const { websiteToken } = window.chatwootWebChannel;
      const upload = new DirectUpload(
        file,
        `/api/v1/widget/direct_uploads?website_token=${websiteToken}`,
        {
          directUploadWillCreateBlobWithXHR: xhr => {
            xhr.setRequestHeader('X-Auth-Token', window.authToken);
          },
        }
      );

      upload.create((error, blob) => {
        this.isUploading = false;
        if (error) {
          this.errorMessage = this.$t('VOICE_RECORDER.ERROR');
          this.recordingState = 'denied';
          this.$emit('recording-state-changed', false);
        } else {
          this.onSendAttachment({
            file: blob.signed_id,
            thumbUrl: thumbUrl,
            fileType: 'audio',
          });
        }
      });
    },
    startTimer() {
      this.stopTimer();
      this.timerInterval = setInterval(() => {
        this.recordingTimer += 1;
      }, 1000);
    },
    stopTimer() {
      if (this.timerInterval) {
        clearInterval(this.timerInterval);
        this.timerInterval = null;
      }
    },
    cleanup() {
      this.stopTimer();
      if (this.stream) {
        this.stream.getTracks().forEach(track => track.stop());
        this.stream = null;
      }
      this.mediaRecorder = null;
      this.recordedChunks = [];
    },
  },
};
</script>

<template>
  <div class="voice-recorder">
    <Spinner v-if="isUploading" size="small" />
    <button
      v-else-if="isIdle && canShowMic && isSupported"
      class="min-h-8 min-w-8 flex items-center justify-center text-n-slate-12"
      :aria-label="$t('VOICE_RECORDER.START')"
      @click="startRecording"
    >
      <FluentIcon icon="microphone" size="20" />
    </button>

    <div v-if="isRecording" class="recording-indicator flex items-center gap-1.5">
      <span class="recording-dot inline-block" />
      <span class="recording-timer text-sm font-medium tabular-nums text-n-slate-12 min-w-[3rem]">
        {{ formattedTime }}
      </span>
      <button
        class="recording-stop-btn min-h-8 min-w-8 flex items-center justify-center"
        :aria-label="$t('VOICE_RECORDER.STOP')"
        @click="stopRecording"
      >
        <FluentIcon icon="stop" size="16" class="text-n-ruby-9" />
      </button>
      <button
        class="min-h-8 min-w-8 flex items-center justify-center text-n-slate-12"
        :aria-label="$t('VOICE_RECORDER.CANCEL')"
        @click="cancelRecording"
      >
        <FluentIcon icon="dismiss" size="18" />
      </button>
    </div>

    <div
      v-if="isError"
      class="recording-error flex items-center gap-1 text-xs text-n-ruby-9"
      role="alert"
    >
      <span class="error-text truncate max-w-[160px]">{{ errorMessage }}</span>
      <button
        class="min-h-8 min-w-8 flex items-center justify-center text-n-slate-12"
        @click="resetRecording"
      >
        <FluentIcon icon="dismiss" size="16" />
      </button>
    </div>
  </div>
</template>

<style scoped lang="scss">
.recording-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: #e53e3e;
  animation: voice-pulse 1.2s ease-in-out infinite;
  flex-shrink: 0;
}

@keyframes voice-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.4;
  }
}
</style>
