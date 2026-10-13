<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import MessageApi from 'dashboard/api/inbox/message';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import MessagePreview from './MessagePreview.vue';

const props = defineProps({
  conversationId: { type: [String, Number], required: true },
  contact: { type: Object, default: () => ({}) },
  inbox: { type: Object, default: () => ({}) },
  anchorEl: { type: Object, default: null },
});

const emit = defineEmits(['close', 'open', 'pointerEnter', 'pointerLeave']);

const VIEWPORT_MARGIN = 8;
const PANEL_GAP = 8;
const MAX_PREVIEW_IMAGES = 4;
const SKELETON_BUBBLES = [
  'self-start w-3/5',
  'self-start w-2/5',
  'self-end w-1/2',
  'self-start w-3/4',
];

const panelRef = ref(null);
const scrollRef = ref(null);
const position = ref({});
const messages = ref([]);
const loadState = ref('loading');

const inboxIcon = computed(() => {
  const {
    channel_type: channelType,
    medium,
    voice_enabled: voiceEnabled,
  } = props.inbox;
  return getInboxIconByType(channelType, medium, 'fill', voiceEnabled);
});

// Consecutive messages from the same sender share one header and timestamp,
// the way the conversation view stacks them.
const messageGroups = computed(() =>
  messages.value.reduce((groups, message) => {
    const isOutgoing = message.message_type !== MESSAGE_TYPE.INCOMING;
    const isPrivate = Boolean(message.private);
    const key = `${message.message_type}-${message.sender?.id}-${isPrivate}`;
    const lastGroup = groups[groups.length - 1];

    if (lastGroup?.key === key) {
      lastGroup.messages.push(message);
      lastGroup.createdAt = message.created_at;
    } else {
      groups.push({
        key,
        isOutgoing,
        isPrivate,
        senderName: isOutgoing ? message.sender?.name : '',
        createdAt: message.created_at,
        messages: [message],
      });
    }
    return groups;
  }, [])
);

const bubbleClass = group => {
  if (group.isPrivate) {
    return 'self-end bg-n-solid-amber text-n-amber-12 ltr:rounded-br-sm rtl:rounded-bl-sm';
  }
  if (group.isOutgoing) {
    return 'self-end bg-n-solid-blue text-n-slate-12 ltr:rounded-br-sm rtl:rounded-bl-sm';
  }
  return 'self-start bg-n-slate-4 text-n-slate-12 ltr:rounded-bl-sm rtl:rounded-br-sm';
};

const imagesOf = message =>
  (message.attachments || []).filter(({ file_type: type }) => type === 'image');

// Images render as thumbnails, so the text line is only needed for a caption
// or for attachments that are not images.
const needsTextPreview = message =>
  Boolean(message.content) ||
  (message.attachments || []).some(({ file_type: type }) => type !== 'image');

const shortTime = timestamp => shortTimestamp(dynamicTime(timestamp));

const updatePosition = () => {
  const anchor = props.anchorEl;
  if (!anchor) return;

  const cardRect = anchor.getBoundingClientRect();
  const { width, height } = panelRef.value.getBoundingClientRect();
  const maxLeft = window.innerWidth - width - VIEWPORT_MARGIN;
  const maxTop = window.innerHeight - height - VIEWPORT_MARGIN;

  // Sit just outside the list on its inline-end side: right of it in LTR,
  // left of it in RTL. The card spans the full width of the list.
  const isRTL = getComputedStyle(anchor).direction === 'rtl';
  const left = isRTL
    ? cardRect.left - PANEL_GAP - width
    : cardRect.right + PANEL_GAP;

  position.value = {
    top: `${Math.max(VIEWPORT_MARGIN, Math.min(cardRect.top, maxTop))}px`,
    left: `${Math.max(VIEWPORT_MARGIN, Math.min(left, maxLeft))}px`,
  };
};

const loadMessages = async () => {
  try {
    // Without a `before` cursor the endpoint returns the latest page.
    const { data } = await MessageApi.getPreviousMessages({
      conversationId: props.conversationId,
    });
    messages.value = data.payload.filter(
      message => message.message_type !== MESSAGE_TYPE.ACTIVITY
    );
    loadState.value = 'ready';
    await nextTick();
  } catch {
    loadState.value = 'error';
    return;
  }

  // The panel may have closed while the request was in flight.
  if (!scrollRef.value) return;
  scrollRef.value.scrollTop = scrollRef.value.scrollHeight;
  updatePosition();
};

// Close only when the hovered card itself moves (the list or the page scrolls),
// not when the panel scrolls its own messages to the bottom.
const onScroll = ({ target }) => {
  if (target.contains(props.anchorEl)) emit('close');
};

onMounted(async () => {
  await nextTick();
  updatePosition();
  loadMessages();
  window.addEventListener('scroll', onScroll, true);
});

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll, true);
});
</script>

<template>
  <Teleport to="body">
    <Transition
      appear
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0 translate-y-1"
    >
      <div
        ref="panelRef"
        class="fixed z-[9999] flex flex-col w-[24rem] overflow-hidden cursor-pointer rounded-xl bg-n-solid-2 shadow-xl outline outline-1 outline-n-container"
        :style="position"
        @mouseenter="emit('pointerEnter')"
        @mouseleave="emit('pointerLeave')"
        @click="emit('open', $event)"
      >
        <div
          class="flex items-center gap-2.5 px-3 py-2.5 border-b border-n-weak"
        >
          <Avatar
            :name="contact.name"
            :src="contact.thumbnail"
            :size="28"
            rounded-full
          />
          <div class="flex flex-col min-w-0">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ contact.name }}
            </span>
            <span
              v-if="inbox.name"
              class="flex items-center min-w-0 gap-1 text-xs text-n-slate-11"
            >
              <Icon :icon="inboxIcon" class="flex-shrink-0 size-3" />
              <span class="truncate">{{ inbox.name }}</span>
            </span>
          </div>
        </div>

        <div
          ref="scrollRef"
          class="flex flex-col gap-3 p-3 overflow-y-auto overscroll-contain max-h-[min(26rem,60vh)]"
        >
          <div
            v-if="loadState === 'loading'"
            role="status"
            class="flex flex-col gap-2"
          >
            <span class="sr-only">
              {{ $t('CHAT_LIST.HOVER_PREVIEW.LOADING') }}
            </span>
            <div
              v-for="(widthClass, index) in SKELETON_BUBBLES"
              :key="index"
              class="h-8 rounded-xl bg-n-alpha-2 animate-pulse"
              :class="widthClass"
            />
          </div>

          <div
            v-else-if="loadState === 'error' || !messageGroups.length"
            class="flex flex-col items-center gap-2 py-6 text-n-slate-10"
          >
            <Icon
              :icon="
                loadState === 'error'
                  ? 'i-lucide-circle-alert'
                  : 'i-lucide-message-circle'
              "
              class="size-5"
            />
            <span class="text-xs">
              {{
                loadState === 'error'
                  ? $t('CHAT_LIST.HOVER_PREVIEW.ERROR')
                  : $t('CHAT_LIST.HOVER_PREVIEW.EMPTY')
              }}
            </span>
          </div>

          <template v-else>
            <div
              v-for="group in messageGroups"
              :key="`${group.key}-${group.messages[0].id}`"
              class="flex flex-col gap-1"
            >
              <span
                v-if="group.isPrivate || group.senderName"
                class="flex items-center self-end gap-1 px-1 text-xs text-n-slate-11"
              >
                <Icon
                  v-if="group.isPrivate"
                  icon="i-lucide-lock-keyhole"
                  class="size-3 text-n-amber-11"
                />
                <span v-if="group.isPrivate">
                  {{ $t('CHAT_LIST.HOVER_PREVIEW.PRIVATE_NOTE') }}
                </span>
                <span
                  v-if="group.isPrivate && group.senderName"
                  class="rounded-full size-0.5 bg-current"
                />
                <span class="truncate">{{ group.senderName }}</span>
              </span>
              <div
                v-for="message in group.messages"
                :key="message.id"
                class="flex flex-col gap-1 max-w-[85%] rounded-xl"
                :class="[
                  bubbleClass(group),
                  needsTextPreview(message) ? 'px-3 py-1.5' : 'p-1',
                ]"
              >
                <div
                  v-if="imagesOf(message).length"
                  class="flex flex-wrap gap-1"
                  :class="{ '-mx-2 mt-0.5': needsTextPreview(message) }"
                >
                  <img
                    v-for="image in imagesOf(message).slice(
                      0,
                      MAX_PREVIEW_IMAGES
                    )"
                    :key="image.id"
                    :src="image.thumb_url || image.data_url"
                    class="object-cover rounded-lg size-24 bg-n-alpha-2"
                    loading="lazy"
                  />
                </div>
                <MessagePreview
                  v-if="needsTextPreview(message)"
                  :message="message"
                  :show-message-type="false"
                  multi-line
                />
              </div>
              <span
                class="px-1 text-[0.6875rem] text-n-slate-10"
                :class="group.isOutgoing ? 'self-end' : 'self-start'"
              >
                {{ shortTime(group.createdAt) }}
              </span>
            </div>
          </template>
        </div>

        <div
          class="flex items-center gap-1.5 px-3 py-2 text-xs border-t border-n-weak text-n-slate-10"
        >
          <Icon icon="i-lucide-mouse-pointer-click" class="size-3.5" />
          {{ $t('CHAT_LIST.HOVER_PREVIEW.OPEN_HINT') }}
        </div>
      </div>
    </Transition>
  </Teleport>
</template>
