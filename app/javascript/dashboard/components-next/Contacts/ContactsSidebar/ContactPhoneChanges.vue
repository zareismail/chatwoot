<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { messageStamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  selectedContact: {
    type: Object,
    default: null,
  },
});

const { t } = useI18n();

// Newest first. Entries are appended by the phone sync, so the stored order is oldest
// first and a contact keeps every number it has ever been given.
//
// The keys are camelCase here: getContactById runs the contact through camelcaseKeys with
// deep: true, so phone_number_history and released_to arrive renamed.
const changes = computed(() =>
  [...(props.selectedContact?.additionalAttributes?.phoneNumberHistory ?? [])]
    .map((change, index) => ({ ...change, id: index }))
    .reverse()
);

const changedAt = change =>
  messageStamp(new Date(change.at).getTime() / 1000, 'LLL d yyyy, h:mm a');
</script>

<template>
  <div v-if="changes.length > 0" class="flex flex-col divide-y divide-n-weak">
    <div v-for="change in changes" :key="change.id" class="px-6 py-4">
      <div class="flex flex-wrap items-center gap-2 text-sm text-n-slate-12">
        <span class="line-through text-n-slate-11" dir="ltr">
          {{ change.from || t('CONTACTS_LAYOUT.SIDEBAR.PHONE_CHANGES.NONE') }}
        </span>
        <i class="i-lucide-arrow-right size-3.5 text-n-slate-10" />
        <span v-if="change.to" dir="ltr" class="font-medium">{{
          change.to
        }}</span>
        <span v-else class="text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.SIDEBAR.PHONE_CHANGES.CLEARED') }}
        </span>
      </div>
      <p class="mt-1 text-xs text-n-slate-11">{{ changedAt(change) }}</p>
      <p v-if="change.releasedTo" class="mt-0.5 text-xs text-n-slate-11">
        {{
          t('CONTACTS_LAYOUT.SIDEBAR.PHONE_CHANGES.RELEASED_TO', {
            identifier: change.releasedTo,
          })
        }}
      </p>
    </div>
  </div>
  <p v-else class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
    {{ t('CONTACTS_LAYOUT.SIDEBAR.PHONE_CHANGES.EMPTY_STATE') }}
  </p>
</template>
