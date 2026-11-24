import { SharedArray } from 'k6/data';
import exec from 'k6/execution';
import papaparse from './lib/papaparse-5.1.1.js';

export class UserDataProvider {
  constructor(name, filePath) {
    this.users = new SharedArray(name, () => {
      const parsed = papaparse.parse(open(decodeURI(filePath)), {
        header: true,
        skipEmptyLines: true,
      });
      return parsed.data;
    });

    if (this.users.length === 0) {
      throw new Error(`El archivo ${filePath} no tiene usuarios`);
    }
  }

  get size() {
    return this.users.length;
  }

  getByVU() {
    const index = (exec.vu.idInTest - 1) % this.users.length;
    return this.users[index];
  }

  getUnique() {
    const index = exec.scenario.iterationInTest % this.users.length;
    return this.users[index];
  }

  getRandom() {
    const index = Math.floor(Math.random() * this.users.length);
    return this.users[index];
  }
}
