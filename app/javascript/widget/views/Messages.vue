<script>
import { mapGetters } from 'vuex';

import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';
import ImageGallery from '../components/ImageGallery.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';
import { IFrameHelper } from 'widget/helpers/utils';

export default {
  components: { ChatFooter, ConversationWrap, ImageGallery },
  data() {
    return {
      showGallery: false,
      galleryStartIndex: 0,
    };
  },
  computed: {
    ...mapGetters({
      groupedMessages: 'conversation/getGroupedConversation',
      allAttachments: 'conversation/getAllAttachments',
      isWidgetOpen: 'appConfig/getIsWidgetOpen',
    }),
    // The host page boots the widget into a hidden iframe on every load, and
    // `/` redirects straight here, so mounting is no sign the reader saw
    // anything. Outside an iframe — the mobile app, the popout — this view is
    // only ever mounted because it is being looked at.
    isBeingRead() {
      return this.isWidgetOpen || !IFrameHelper.isIFrame();
    },
  },
  watch: {
    isBeingRead: {
      immediate: true,
      handler(isBeingRead) {
        if (isBeingRead) {
          this.$store.dispatch('conversation/setUserLastSeen');
        }
      },
    },
  },
  mounted() {
    emitter.on(BUS_EVENTS.OPEN_GALLERY, this.onOpenGallery);
  },
  unmounted() {
    emitter.off(BUS_EVENTS.OPEN_GALLERY, this.onOpenGallery);
  },
  methods: {
    onOpenGallery(url) {
      const index = this.allAttachments.findIndex(
        attachment => attachment.data_url === url
      );
      if (index !== -1) {
        this.galleryStartIndex = index;
        this.showGallery = true;
      }
    },
    onCloseGallery() {
      this.showGallery = false;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 overflow-hidden rounded-b-lg bg-n-slate-2 dark:bg-n-solid-1"
  >
    <div class="flex flex-1 overflow-auto">
      <ConversationWrap :grouped-messages="groupedMessages" />
    </div>
    <ChatFooter class="px-5" />
    <ImageGallery
      v-model:show="showGallery"
      :attachments="allAttachments"
      :start-index="galleryStartIndex"
      @close="onCloseGallery"
    />
  </div>
</template>
