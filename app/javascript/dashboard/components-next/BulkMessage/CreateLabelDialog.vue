<script setup>
import { reactive, ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { getRandomColor } from 'dashboard/helper/labelColor';
import validations, {
  getLabelTitleErrorMessage,
} from 'dashboard/routes/dashboard/settings/labels/validations';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ColorPicker from 'dashboard/components-next/colorpicker/ColorPicker.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const emit = defineEmits(['created']);

const { t } = useI18n();
const store = useStore();

const state = reactive({
  title: '',
  description: '',
  color: '',
  showOnSidebar: true,
});

const v$ = useVuelidate(validations, state);

const isCreating = ref(false);
const dialogRef = ref(null);

const titleError = computed(() => t(getLabelTitleErrorMessage(v$.value)));

const open = () => {
  Object.assign(state, {
    title: '',
    description: '',
    color: getRandomColor(),
    showOnSidebar: true,
  });
  v$.value.$reset();
  dialogRef.value?.open();
};

const handleCreate = async () => {
  if (!(await v$.value.$validate())) return;

  const title = state.title.toLowerCase();
  isCreating.value = true;
  try {
    await store.dispatch('labels/create', {
      title,
      description: state.description,
      color: state.color,
      show_on_sidebar: state.showOnSidebar,
    });
    useAlert(t('LABEL_MGMT.ADD.API.SUCCESS_MESSAGE'));
    emit('created', title);
    dialogRef.value?.close();
  } catch (error) {
    useAlert(error.message || t('LABEL_MGMT.ADD.API.ERROR_MESSAGE'));
  } finally {
    isCreating.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="md"
    :title="t('LABEL_MGMT.ADD.TITLE')"
    :description="t('LABEL_MGMT.ADD.DESC')"
    :confirm-button-label="t('LABEL_MGMT.FORM.CREATE')"
    :is-loading="isCreating"
    :disable-confirm-button="v$.title.$invalid"
    @confirm="handleCreate"
  >
    <Input
      v-model="state.title"
      :label="t('LABEL_MGMT.FORM.NAME.LABEL')"
      :placeholder="t('LABEL_MGMT.FORM.NAME.PLACEHOLDER')"
      :message="titleError"
      :message-type="titleError ? 'error' : 'info'"
      custom-input-class="lowercase"
      @blur="v$.title.$touch"
    />
    <Input
      v-model="state.description"
      :label="t('LABEL_MGMT.FORM.DESCRIPTION.LABEL')"
      :placeholder="t('LABEL_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
    />
    <div class="flex flex-col gap-1">
      <span class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('LABEL_MGMT.FORM.COLOR.LABEL') }}
      </span>
      <ColorPicker v-model="state.color" />
    </div>
    <label class="flex items-center gap-2 text-sm text-n-slate-12">
      <Checkbox v-model="state.showOnSidebar" />
      {{ t('LABEL_MGMT.FORM.SHOW_ON_SIDEBAR.LABEL') }}
    </label>
  </Dialog>
</template>
