<script>
const MINUTE_IN_MILLI_SECONDS = 60000;
const HOUR_IN_MILLI_SECONDS = MINUTE_IN_MILLI_SECONDS * 60;
const DAY_IN_MILLI_SECONDS = HOUR_IN_MILLI_SECONDS * 24;

import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';

export default {
  name: 'TimeAgo',
  props: {
    isAutoRefreshEnabled: {
      type: Boolean,
      default: true,
    },
    lastActivityTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    createdAtTimestamp: {
      type: [String, Date, Number],
      default: '',
    },
    conversationId: {
      type: [String, Number],
      default: '',
    },
    contactLastSeenAt: {
      type: [String, Date, Number],
      default: 0,
    },
    agentLastSeenAt: {
      type: [String, Date, Number],
      default: 0,
    },
  },
  setup() {
    return { exactTimestamp: useExactTimestamp() };
  },
  data() {
    return {
      lastActivityAtTimeAgo: dynamicTime(this.lastActivityTimestamp),
      createdAtTimeAgo: dynamicTime(this.createdAtTimestamp),
      contactLastSeenTimeAgo: this.contactLastSeenAt
        ? dynamicTime(this.contactLastSeenAt)
        : '',
      agentLastSeenTimeAgo: this.agentLastSeenAt
        ? dynamicTime(this.agentLastSeenAt)
        : '',
      timer: null,
    };
  },
  computed: {
    lastActivityTime() {
      return shortTimestamp(this.lastActivityAtTimeAgo);
    },
    createdAtTime() {
      return shortTimestamp(this.createdAtTimeAgo);
    },
    contactLastSeenDisplay() {
      if (!this.contactLastSeenAt) return '';
      return shortTimestamp(this.contactLastSeenTimeAgo);
    },
    agentLastSeenDisplay() {
      if (!this.agentLastSeenAt) return '';
      return shortTimestamp(this.agentLastSeenTimeAgo);
    },
    createdAt() {
      return `${this.$t(
        'CHAT_LIST.CHAT_TIME_STAMP.CREATED.OLDEST'
      )} ${this.exactTimestamp(this.createdAtTimestamp)}`;
    },
    lastActivity() {
      return `${this.$t(
        'CHAT_LIST.CHAT_TIME_STAMP.LAST_ACTIVITY.NOT_ACTIVE'
      )} ${this.exactTimestamp(this.lastActivityTimestamp)}`;
    },
    tooltipText() {
      const lines = [this.createdAt, this.lastActivity];
      if (this.contactLastSeenAt) {
        const contactDiff = Date.now() - this.contactLastSeenAt * 1000;
        const contactTime =
          contactDiff > DAY_IN_MILLI_SECONDS * 30
            ? this.exactTimestamp(this.contactLastSeenAt)
            : this.contactLastSeenTimeAgo;
        lines.push(
          `${this.$t('CHAT_LIST.CHAT_TIME_STAMP.LAST_SEEN.CONTACT')} ${contactTime}`
        );
      }
      if (this.agentLastSeenAt) {
        const agentDiff = Date.now() - this.agentLastSeenAt * 1000;
        const agentTime =
          agentDiff > DAY_IN_MILLI_SECONDS * 30
            ? this.exactTimestamp(this.agentLastSeenAt)
            : this.agentLastSeenTimeAgo;
        lines.push(
          `${this.$t('CHAT_LIST.CHAT_TIME_STAMP.LAST_SEEN.AGENT')} ${agentTime}`
        );
      }
      return lines.join('\n');
    },
  },
  watch: {
    lastActivityTimestamp() {
      this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
    },
    createdAtTimestamp() {
      this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
    },
    conversationId() {
      // Reset display values and timer when the row is recycled to a different conversation.
      this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
      this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
      this.contactLastSeenTimeAgo = this.contactLastSeenAt
        ? dynamicTime(this.contactLastSeenAt)
        : '';
      this.agentLastSeenTimeAgo = this.agentLastSeenAt
        ? dynamicTime(this.agentLastSeenAt)
        : '';
      if (this.isAutoRefreshEnabled) {
        clearTimeout(this.timer);
        this.createTimer();
      }
    },
  },
  mounted() {
    if (this.isAutoRefreshEnabled) {
      this.createTimer();
    }
  },
  unmounted() {
    clearTimeout(this.timer);
  },
  methods: {
    createTimer() {
      this.timer = setTimeout(() => {
        this.lastActivityAtTimeAgo = dynamicTime(this.lastActivityTimestamp);
        this.createdAtTimeAgo = dynamicTime(this.createdAtTimestamp);
        this.createTimer();
      }, this.refreshTime());
    },
    refreshTime() {
      const timeDiff = Date.now() - this.lastActivityTimestamp * 1000;
      if (timeDiff > DAY_IN_MILLI_SECONDS) {
        return DAY_IN_MILLI_SECONDS;
      }
      if (timeDiff > HOUR_IN_MILLI_SECONDS) {
        return HOUR_IN_MILLI_SECONDS;
      }

      return MINUTE_IN_MILLI_SECONDS;
    },
  },
};
</script>

<template>
  <div
    v-tooltip.top="{
      content: tooltipText,
      popperClass: 'whitespace-pre-line',
      delay: { show: 1000, hide: 0 },
    }"
    class="ml-auto leading-4 text-xxs text-n-slate-10 hover:text-n-slate-11"
  >
    <span>{{ `${createdAtTime} • ${lastActivityTime}` }}</span>
    <span v-if="contactLastSeenDisplay" class="block text-n-slate-9">
      {{ contactLastSeenDisplay }}
      <span v-if="agentLastSeenDisplay" class="text-n-slate-8">
        · {{ agentLastSeenDisplay }}
      </span>
    </span>
  </div>
</template>
