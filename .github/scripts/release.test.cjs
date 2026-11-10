const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test, before, after } = require('node:test');
const publish = require('./release.cjs');

const originalCwd = process.cwd();
let temporary;
before(() => {
  temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'dice-math-release-'));
  process.chdir(temporary);
  fs.mkdirSync('build/app/outputs/flutter-apk', { recursive: true });
  fs.writeFileSync('build/app/outputs/flutter-apk/app-release.apk', 'test APK');
});
after(() => {
  process.chdir(originalCwd);
  fs.rmSync(temporary, { recursive: true, force: true });
});

function fixture() {
  const calls = [];
  const missing = Object.assign(new Error('Not found'), { status: 404 });
  const published = (id) => ({
    id,
    tag_name: `ci-apk-${id}-abcdef012345`,
    draft: false,
    published_at: new Date(2026, 0, id).toISOString(),
  });
  const current = { ...published(20), html_url: 'https://github.com/owner/repo/releases/tag/ci-apk-20-abcdef012345' };
  const context = {
    repo: { owner: 'owner', repo: 'repo' },
    sha: 'abcdef0123456789abcdef0123456789abcdef01',
    runNumber: 20,
    runId: 200,
    serverUrl: 'https://github.com',
  };
  const state = {
    existing: null,
    message: 'Fix "dice" math $(do-not-run) `literal`\n\nFull message\nwith multiple lines.',
    releases: Array.from({ length: 20 }, (_, i) => published(i + 1)).reverse(),
    assets: [],
    uploadError: null,
    deleteError: null,
    tagError: null,
  };
  const repos = {
    getCommit: async () => ({ data: { commit: { message: state.message } } }),
    getReleaseByTag: async () => {
      if (state.existing) return { data: state.existing };
      throw missing;
    },
    createRelease: async (args) => {
      calls.push(['create', args]);
      return { data: { ...current, draft: true } };
    },
    listReleaseAssets: async () => {},
    listReleases: async () => {},
    deleteReleaseAsset: async (args) => calls.push(['delete-asset', args]),
    uploadReleaseAsset: async (args) => {
      calls.push(['upload', args]);
      if (state.uploadError) throw state.uploadError;
    },
    updateRelease: async (args) => {
      calls.push(['publish', args]);
      return { data: current };
    },
    deleteRelease: async (args) => {
      calls.push(['delete-release', args]);
      if (state.deleteError) throw state.deleteError;
    },
  };
  const github = {
    rest: { repos, git: { deleteRef: async (args) => {
      calls.push(['delete-tag', args]);
      if (state.tagError) throw state.tagError;
    } } },
    paginate: async (method) => {
      if (method === repos.listReleaseAssets) return state.assets;
      assert.equal(method, repos.listReleases);
      calls.push(['list-releases']);
      return state.releases;
    },
  };
  const summary = {
    addLink: (...args) => { calls.push(['summary', ...args]); return summary; },
    addRaw: () => summary,
    write: async () => {},
  };
  return { args: { github, context, core: { info() {}, summary } }, calls, state, current };
}

test('publishes the exact commit message and APK before pruning to 10 releases', async () => {
  const { args, calls, state } = fixture();
  // Deliberately scramble ordering: retention must use publication time.
  state.releases.reverse();
  state.releases.push({ id: 100, tag_name: 'v1.0.0', draft: false });
  state.releases.push({ id: 101, tag_name: 'ci-apk-not-a-build', draft: false });
  state.releases.push({ id: 102, tag_name: 'ci-apk-102-abcdef012345', draft: true });
  await publish(args);
  const created = calls.find(([name]) => name === 'create')[1];
  assert.ok(created.name.startsWith(state.message.split('\n')[0]));
  assert.ok(created.body.startsWith(`${state.message}\n\n---\n`));
  assert.equal(created.target_commitish, args.context.sha);
  assert.equal(created.draft, true);
  const uploaded = calls.find(([name]) => name === 'upload')[1];
  assert.equal(uploaded.data.toString(), 'test APK');
  assert.equal(uploaded.name, 'dice-math-abcdef012345.apk');
  const removed = calls.filter(([name]) => name === 'delete-release').map(([, args]) => args.release_id);
  assert.deepEqual(removed, [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
  const tags = calls.filter(([name]) => name === 'delete-tag').map(([, args]) => args.ref);
  assert.deepEqual(tags, removed.map((id) => `tags/ci-apk-${id}-abcdef012345`));
  assert.ok(calls.findIndex(([name]) => name === 'upload') < calls.findIndex(([name]) => name === 'publish'));
  assert.ok(calls.findIndex(([name]) => name === 'publish') < calls.findIndex(([name]) => name === 'delete-release'));
  assert.equal(calls.find(([name]) => name === 'summary')[2],
    'https://github.com/owner/repo/releases/download/ci-apk-20-abcdef012345/dice-math-abcdef012345.apk');
});

test('an upload failure leaves the draft retryable and never prunes releases', async () => {
  const { args, calls, state } = fixture();
  state.uploadError = new Error('Upload failed');
  await assert.rejects(publish(args), /Upload failed/);
  assert.equal(calls.some(([name]) => ['publish', 'list-releases', 'delete-release', 'delete-tag'].includes(name)), false);
});

test('reruns preserve the existing published APK instead of signing it again', async () => {
  const { args, calls, state, current } = fixture();
  state.existing = current;
  state.releases = [current];
  await publish(args);
  assert.equal(calls.some(([name]) => ['create', 'upload', 'delete-release', 'delete-tag'].includes(name)), false);
});

test('a failed draft upload can be replaced on retry', async () => {
  const { args, calls, state, current } = fixture();
  state.existing = { ...current, draft: true };
  state.assets = [{ id: 7, name: 'dice-math-abcdef012345.apk' }];
  state.releases = [current];
  await publish(args);
  assert.equal(calls.some(([name]) => name === 'create'), false);
  assert.deepEqual(calls.find(([name]) => name === 'delete-asset')[1].asset_id, 7);
  assert.ok(calls.findIndex(([name]) => name === 'delete-asset') < calls.findIndex(([name]) => name === 'upload'));
});

test('concurrent cleanup tolerates already deleted releases and tags', async () => {
  const { args, state } = fixture();
  state.deleteError = Object.assign(new Error('Not found'), { status: 404 });
  state.tagError = Object.assign(new Error('Reference does not exist'), { status: 422 });
  await publish(args);
});

test('cleanup permission errors fail visibly and do not delete the associated tag', async () => {
  const { args, calls, state } = fixture();
  state.deleteError = Object.assign(new Error('Forbidden'), { status: 403 });
  await assert.rejects(publish(args), /Forbidden/);
  assert.equal(calls.some(([name]) => name === 'delete-tag'), false);
});

test('unexpected tag errors are not mistaken for a concurrent deletion', async () => {
  const { args, state } = fixture();
  state.tagError = Object.assign(new Error('Protected tag'), { status: 422 });
  await assert.rejects(publish(args), /Protected tag/);
});
