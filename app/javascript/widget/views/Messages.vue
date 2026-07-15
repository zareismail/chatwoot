<script>
import { mapGetters } from 'vuex';

import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';
import ImageGallery from '../components/ImageGallery.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

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
      allImageAttachments: 'conversation/getAllImageAttachments',
    }),
  },
  mounted() {
    this.$store.dispatch('conversation/setUserLastSeen');
    emitter.on(BUS_EVENTS.OPEN_GALLERY, this.onOpenGallery);
  },
  unmounted() {
    emitter.off(BUS_EVENTS.OPEN_GALLERY, this.onOpenGallery);
  },
  methods: {
    onOpenGallery(url) {
      const index = this.allImageAttachments.findIndex(
        img => img.data_url === url
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
      :images="allImageAttachments"
      :start-index="galleryStartIndex"
      @close="onCloseGallery"
    />
  </div>
</template>
