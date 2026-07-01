<script setup>
import { reactive, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { DirectUpload } from 'activestorage';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

import BulkMessagesAPI from 'dashboard/api/bulkMessages';

const { t } = useI18n();

const accountId = useMapGetter('getCurrentAccountId');
const currentUser = useMapGetter('getCurrentUser');
const websiteInboxes = useMapGetter('inboxes/getWebsiteInboxes');

const initialState = {
  inboxId: null,
  content: '',
  phoneNumbers: '',
};

const state = reactive({ ...initialState });

const rules = {
  inboxId: { required },
  content: { required, minLength: minLength(1) },
  phoneNumbers: { required, minLength: minLength(1) },
};

const v$ = useVuelidate(rules, state);

const isSending = ref(false);
const fileInput = ref(null);
// Each entry: { file: File, isUploading: boolean, signedId: string|null }
const attachments = ref([]);

const inboxOptions = computed(() =>
  (websiteInboxes.value || []).map(inbox => ({
    value: inbox.id,
    label: inbox.name,
  }))
);

const phoneNumberCount = computed(() => {
  return state.phoneNumbers
    .split(/[,;\n]+/)
    .map(number => number.trim())
    .filter(number => number.length).length;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'BULK_MESSAGE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  inbox: getErrorMessage('inboxId', 'INBOX'),
  content: getErrorMessage('content', 'CONTENT'),
  phoneNumbers: getErrorMessage('phoneNumbers', 'PHONE_NUMBERS'),
}));

const isUploadingAnyFile = computed(() =>
  attachments.value.some(attachment => attachment.isUploading)
);

const isSubmitDisabled = computed(
  () => v$.value.$invalid || isSending.value || isUploadingAnyFile.value
);

const handleFileClick = () => fileInput.value?.click();

const handleRemoveFile = index => {
  attachments.value.splice(index, 1);
};

const uploadFile = attachment => {
  const upload = new DirectUpload(
    attachment.file,
    `/api/v1/accounts/${accountId.value}/direct_uploads`,
    {
      directUploadWillCreateBlobWithXHR: xhr => {
        xhr.setRequestHeader('api_access_token', currentUser.value.access_token);
      },
    }
  );

  upload.create((error, blob) => {
    attachment.isUploading = false;
    if (error) {
      useAlert(error);
      attachments.value = attachments.value.filter(a => a !== attachment);
    } else {
      attachment.signedId = blob.signed_id;
    }
  });
};

const handleFileChange = () => {
  const files = Array.from(fileInput.value?.files || []);
  files.forEach(file => {
    const attachment = reactive({ file, isUploading: true, signedId: null });
    attachments.value.push(attachment);
    uploadFile(attachment);
  });
  if (fileInput.value) fileInput.value.value = null;
};

const resetState = () => {
  Object.assign(state, initialState);
  attachments.value = [];
  if (fileInput.value) fileInput.value.value = null;
  v$.value.$reset();
};

const dialogRef = ref(null);
const open = () => dialogRef.value?.open();
const close = () => {
  dialogRef.value?.close();
  resetState();
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;

  isSending.value = true;
  try {
    await BulkMessagesAPI.create({
      inbox_id: state.inboxId,
      content: state.content,
      phone_numbers: state.phoneNumbers,
      attachments: attachments.value.map(attachment => attachment.signedId).filter(Boolean),
    });
    useAlert(t('BULK_MESSAGE.FORM.API.SUCCESS_MESSAGE'));
    close();
  } catch (error) {
    useAlert(error?.response?.message || t('BULK_MESSAGE.FORM.API.ERROR_MESSAGE'));
  } finally {
    isSending.value = false;
  }
};

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('BULK_MESSAGE.FORM.TITLE')"
    :description="t('BULK_MESSAGE.FORM.DESCRIPTION')"
    :confirm-button-label="t('BULK_MESSAGE.FORM.BUTTONS.SEND')"
    :is-loading="isSending"
    :disable-confirm-button="isSubmitDisabled"
    @confirm="handleSubmit"
    @close="resetState"
  >
    <div class="flex flex-col gap-1">
      <label for="bulk-message-inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('BULK_MESSAGE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="bulk-message-inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('BULK_MESSAGE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
      />
    </div>

    <div class="flex flex-col gap-2">
      <Editor
        v-model="state.content"
        channel-type="Channel::WebWidget"
        :label="t('BULK_MESSAGE.FORM.CONTENT.LABEL')"
        :placeholder="t('BULK_MESSAGE.FORM.CONTENT.PLACEHOLDER')"
        :max-length="4000"
        :message="formErrors.content"
        :message-type="formErrors.content ? 'error' : 'info'"
      />

      <div class="flex flex-col gap-1.5">
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="flex items-center gap-1.5 px-2 py-1 text-xs rounded-md text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 border border-dashed border-n-weak hover:border-n-slate-6 transition-colors"
            @click="handleFileClick"
          >
            <span class="i-lucide-paperclip size-3.5" />
            {{ t('BULK_MESSAGE.FORM.ATTACHMENT.CHOOSE_FILE') }}
          </button>
          <span class="text-xs text-n-slate-10">
            {{ t('BULK_MESSAGE.FORM.ATTACHMENT.HINT') }}
          </span>
        </div>
        <div v-if="attachments.length" class="flex flex-wrap gap-1.5">
          <div
            v-for="(attachment, index) in attachments"
            :key="attachment.file.name + index"
            class="flex items-center gap-1 px-2 py-1 text-xs rounded-md bg-n-alpha-2 text-n-slate-12 border border-n-weak"
          >
            <span class="i-lucide-file size-3 text-n-slate-10 shrink-0" />
            <span class="truncate max-w-[10rem]">{{ attachment.file.name }}</span>
            <span v-if="attachment.isUploading" class="text-n-slate-10 shrink-0">
              {{ t('BULK_MESSAGE.FORM.ATTACHMENT.UPLOADING') }}
            </span>
            <button
              type="button"
              class="i-lucide-x size-3 text-n-slate-10 hover:text-n-ruby-9 shrink-0 ml-0.5"
              @click="handleRemoveFile(index)"
            />
          </div>
        </div>
      </div>

      <input
        ref="fileInput"
        type="file"
        multiple
        accept="video/*,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.zip,.txt"
        class="hidden"
        @change="handleFileChange"
      />
    </div>

    <TextArea
      v-model="state.phoneNumbers"
      :label="t('BULK_MESSAGE.FORM.PHONE_NUMBERS.LABEL')"
      :placeholder="t('BULK_MESSAGE.FORM.PHONE_NUMBERS.PLACEHOLDER')"
      :message="formErrors.phoneNumbers || t('BULK_MESSAGE.FORM.PHONE_NUMBERS.COUNT', { count: phoneNumberCount })"
      :message-type="formErrors.phoneNumbers ? 'error' : 'info'"
    />
  </Dialog>
</template>
