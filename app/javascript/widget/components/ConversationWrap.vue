<script>
import ChatMessage from 'widget/components/ChatMessage.vue';
import AgentTypingBubble from 'widget/components/AgentTypingBubble.vue';
import DateSeparator from 'shared/components/DateSeparator.vue';
import Spinner from 'shared/components/Spinner.vue';
import { useDarkMode } from 'widget/composables/useDarkMode';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { mapActions, mapGetters } from 'vuex';

const SCROLL_TO_BOTTOM_THRESHOLD = 50;

export default {
  name: 'ConversationWrap',
  components: {
    ChatMessage,
    AgentTypingBubble,
    DateSeparator,
    Spinner,
  },
  props: {
    groupedMessages: {
      type: Array,
      default: () => [],
    },
  },
  setup() {
    const { darkMode } = useDarkMode();
    return { darkMode };
  },
  data() {
    return {
      previousScrollHeight: 0,
      previousConversationSize: 0,
      isScrolledToBottom: true,
      lastSeenMessageId: null,
    };
  },
  computed: {
    ...mapGetters({
      conversation: 'conversation/getConversation',
      earliestMessage: 'conversation/getEarliestMessage',
      lastMessage: 'conversation/getLastMessage',
      allMessagesLoaded: 'conversation/getAllMessagesLoaded',
      isFetchingList: 'conversation/getIsFetchingList',
      conversationSize: 'conversation/getConversationSize',
      isAgentTyping: 'conversation/getIsAgentTyping',
      conversationAttributes: 'conversationAttributes/getConversationParams',
    }),
    colorSchemeClass() {
      return `${this.darkMode === 'dark' ? 'dark-scheme' : 'light-scheme'}`;
    },
    isLastMessageFromUser() {
      return this.lastMessage.message_type === MESSAGE_TYPE.INCOMING;
    },
    // Only agent messages that arrived after the last one the user saw count as
    // unread. The user's own messages, activity events and the history that
    // gets prepended while scrolling up are all part of the list too, so a
    // plain message count would report unread messages when there are none.
    unreadCount() {
      const messages = Object.values(this.conversation);
      const lastSeenIndex = messages.findIndex(
        message => message.id === this.lastSeenMessageId
      );
      if (lastSeenIndex === -1) return 0;

      return messages
        .slice(lastSeenIndex + 1)
        .filter(message => message.message_type === MESSAGE_TYPE.OUTGOING)
        .length;
    },
    showStatusIndicator() {
      const { status } = this.conversationAttributes;
      const isConversationInPendingStatus = status === 'pending';
      const isLastMessageIncoming =
        this.lastMessage.message_type === MESSAGE_TYPE.INCOMING;
      return (
        this.isAgentTyping ||
        (isConversationInPendingStatus && isLastMessageIncoming)
      );
    },
  },
  watch: {
    allMessagesLoaded() {
      this.previousScrollHeight = 0;
    },
  },
  mounted() {
    this.$refs.scrollContainer.addEventListener('scroll', this.handleScroll);
    this.previousConversationSize = this.conversationSize;
    this.scrollToBottom();
    this.markAsSeen();
  },
  beforeUpdate() {
    this.isScrolledToBottom = this.isAtBottom();
  },
  updated() {
    if (this.previousConversationSize === this.conversationSize) return;

    this.previousConversationSize = this.conversationSize;

    // previousScrollHeight is only set while older messages are being
    // prepended, where scrollToBottom restores the reading position instead.
    if (this.previousScrollHeight) {
      this.scrollToBottom();
      return;
    }

    if (this.isScrolledToBottom || this.isLastMessageFromUser) {
      this.scrollToBottom();
      this.markAsSeen();
    }
  },
  beforeUnmount() {
    this.$refs.scrollContainer.removeEventListener('scroll', this.handleScroll);
  },
  methods: {
    ...mapActions('conversation', ['fetchOldConversations']),
    isAtBottom() {
      const { scrollTop, scrollHeight, clientHeight } =
        this.$refs.scrollContainer;
      return (
        scrollHeight - scrollTop - clientHeight < SCROLL_TO_BOTTOM_THRESHOLD
      );
    },
    markAsSeen() {
      this.lastSeenMessageId = this.lastMessage.id ?? null;
    },
    scrollToBottom() {
      const container = this.$refs.scrollContainer;
      container.scrollTop = container.scrollHeight - this.previousScrollHeight;
      this.previousScrollHeight = 0;
      this.isScrolledToBottom = this.isAtBottom();
    },
    jumpToLatest() {
      const container = this.$refs.scrollContainer;
      container.scrollTo({ top: container.scrollHeight, behavior: 'smooth' });
      this.markAsSeen();
    },
    handleScroll() {
      const container = this.$refs.scrollContainer;
      this.isScrolledToBottom = this.isAtBottom();
      if (this.isScrolledToBottom) {
        this.markAsSeen();
      }

      if (
        this.isFetchingList ||
        this.allMessagesLoaded ||
        !this.conversationSize
      ) {
        return;
      }

      if (container.scrollTop < 100) {
        this.fetchOldConversations({ before: this.earliestMessage.id });
        this.previousScrollHeight = container.scrollHeight;
      }
    },
  },
};
</script>

<template>
  <div class="relative flex flex-1 overflow-hidden">
    <div
      ref="scrollContainer"
      class="conversation--container"
      :class="colorSchemeClass"
    >
      <div class="conversation-wrap" :class="{ 'is-typing': isAgentTyping }">
        <div v-if="isFetchingList" class="message--loader">
          <Spinner />
        </div>
        <div
          v-for="groupedMessage in groupedMessages"
          :key="groupedMessage.date"
          class="messages-wrap"
        >
          <DateSeparator :date="groupedMessage.date" />
          <ChatMessage
            v-for="message in groupedMessage.messages"
            :key="message.id"
            :message="message"
          />
        </div>
        <AgentTypingBubble v-if="showStatusIndicator" />
      </div>
    </div>
    <button
      v-if="!isScrolledToBottom"
      class="absolute z-20 flex items-center gap-1 px-3 py-1.5 -translate-x-1/2 text-xs font-medium rounded-full shadow-md bottom-3 left-1/2 bg-n-background dark:bg-n-solid-3 text-n-slate-12"
      @click="jumpToLatest"
    >
      <i class="i-lucide-arrow-down size-3" />
      {{ unreadCount ? $t('NEW_MESSAGES', unreadCount) : $t('JUMP_TO_LATEST') }}
    </button>
  </div>
</template>

<style scoped lang="scss">
.conversation--container {
  display: flex;
  flex-direction: column;
  flex: 1;
  overflow-y: auto;
  color-scheme: light dark;

  &.light-scheme {
    color-scheme: light;
  }

  &.dark-scheme {
    color-scheme: dark;
  }
}

.conversation-wrap {
  flex: 1;
  @apply px-2 pt-8 pb-2;
}

.message--loader {
  text-align: center;
}
</style>
