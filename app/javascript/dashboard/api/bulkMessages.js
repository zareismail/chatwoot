import ApiClient from './ApiClient';

class BulkMessagesAPI extends ApiClient {
  constructor() {
    super('bulk_messages', { accountScoped: true });
  }
}

export default new BulkMessagesAPI();
