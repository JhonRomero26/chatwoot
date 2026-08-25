/* global axios */
import { DataManager } from '../helper/CacheHelper/DataManager';
import ApiClient from './ApiClient';

class CacheEnabledApiClient extends ApiClient {
  // These clients are module level singletons while `accountIdFromRoute` is
  // resolved from the URL on every access. Building the DataManager once in the
  // constructor freezes it to whichever account was in the URL at import time
  // (an empty string when the app boots from `/`), which leaks the cached
  // records of one account into another. Rebuild it whenever the account changes.
  get dataManager() {
    const accountId = this.accountIdFromRoute;

    if (this.dataManagerAccountId !== accountId) {
      this.dataManagerAccountId = accountId;
      this.cachedDataManager = new DataManager(accountId);
    }

    return this.cachedDataManager;
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    throw new Error('cacheModelName is not defined');
  }

  get(cache = false) {
    if (cache) {
      return this.getFromCache();
    }

    return this.getFromNetwork();
  }

  getFromNetwork() {
    return axios.get(this.url);
  }

  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data.payload;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: { payload: dataToParse } };
  }

  async getFromCache() {
    try {
      // IDB is not supported in Firefox private mode: https://bugzilla.mozilla.org/show_bug.cgi?id=781982
      await this.dataManager.initDb();
    } catch {
      return this.getFromNetwork();
    }

    const { data } = await axios.get(
      `/api/v1/accounts/${this.accountIdFromRoute}/cache_keys`
    );
    const cacheKeyFromApi = data.cache_keys[this.cacheModelName];
    const isCacheValid = await this.validateCacheKey(cacheKeyFromApi);

    let localData = [];
    if (isCacheValid) {
      localData = await this.dataManager.get({
        modelName: this.cacheModelName,
      });
    }

    if (localData.length === 0) {
      return this.refetchAndCommit(cacheKeyFromApi);
    }

    return this.marshallData(localData);
  }

  async refetchAndCommit(newKey = null) {
    const response = await this.getFromNetwork();

    try {
      await this.dataManager.initDb();

      this.dataManager.replace({
        modelName: this.cacheModelName,
        data: this.extractDataFromResponse(response),
      });

      await this.dataManager.setCacheKeys({
        [this.cacheModelName]: newKey,
      });
    } catch {
      // Ignore error
    }

    return response;
  }

  async validateCacheKey(cacheKeyFromApi) {
    if (!this.dataManager.db) {
      await this.dataManager.initDb();
    }

    const cachekey = await this.dataManager.getCacheKey(this.cacheModelName);
    return cacheKeyFromApi === cachekey;
  }
}

export default CacheEnabledApiClient;
