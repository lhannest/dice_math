const fs = require('node:fs');

const apkPath = 'build/app/outputs/flutter-apk/app-release.apk';
const ciTag = /^ci-apk-\d+-[0-9a-f]{12}$/;

module.exports = async function publish({ github, context, core }) {
  // Read the artifact before making any remote changes.
  const apk = fs.readFileSync(apkPath);
  const repo = context.repo;
  const shortSha = context.sha.slice(0, 12);
  const tag = `ci-apk-${context.runNumber}-${shortSha}`;
  const assetName = `dice-math-${shortSha}.apk`;
  const { data: commit } = await github.rest.repos.getCommit({
    ...repo,
    ref: context.sha,
  });
  const message = commit.commit.message;
  const subject = message.split(/\r?\n/, 1)[0];
  const body = `${message}\n\n---\nCommit: ${context.sha}\nBuild: ${context.serverUrl}/${repo.owner}/${repo.repo}/actions/runs/${context.runId}\n`;

  let release;
  try {
    ({ data: release } = await github.rest.repos.getReleaseByTag({
      ...repo,
      tag,
    }));
  } catch (error) {
    if (error.status !== 404) throw error;
    ({ data: release } = await github.rest.repos.createRelease({
      ...repo,
      tag_name: tag,
      target_commitish: context.sha,
      name: `${subject.slice(0, 200)} (${shortSha})`,
      body,
      draft: true,
    }));
  }

  // A successful rerun keeps the existing APK and signing key. A failed upload
  // leaves a draft that a subsequent rerun can complete.
  if (release.draft) {
    const assets = await github.paginate(github.rest.repos.listReleaseAssets, {
      ...repo,
      release_id: release.id,
      per_page: 100,
    });
    for (const asset of assets.filter((asset) => asset.name === assetName)) {
      await github.rest.repos.deleteReleaseAsset({ ...repo, asset_id: asset.id });
    }
    await github.rest.repos.uploadReleaseAsset({
      ...repo,
      release_id: release.id,
      name: assetName,
      data: apk,
      headers: { 'content-type': 'application/vnd.android.package-archive' },
    });
    ({ data: release } = await github.rest.repos.updateRelease({
      ...repo,
      release_id: release.id,
      draft: false,
      make_latest: 'true',
    }));
  }

  core.info(`Published ${release.html_url}`);
  await core.summary.addLink('Download APK', `${context.serverUrl}/${repo.owner}/${repo.repo}/releases/download/${tag}/${assetName}`)
    .addRaw(`\n\nCommit: ${context.sha}\n`).write();

  const releases = await github.paginate(github.rest.repos.listReleases, {
    ...repo,
    per_page: 100,
  });
  const published = releases
    .filter((item) => !item.draft && ciTag.test(item.tag_name))
    .sort((a, b) => Date.parse(b.published_at) - Date.parse(a.published_at) || b.id - a.id);

  for (const old of published.slice(10)) {
    // Parallel builds may attempt to prune the same release. Ignore only 404s;
    // permission errors and other failures must remain visible in the run.
    try {
      await github.rest.repos.deleteRelease({ ...repo, release_id: old.id });
    } catch (error) {
      if (error.status !== 404) throw error;
    }
    try {
      await github.rest.git.deleteRef({ ...repo, ref: `tags/${old.tag_name}` });
    } catch (error) {
      if (error.status !== 404 && error.status !== 422) throw error;
      // GitHub returns 422 when another run has already removed the tag.
      if (error.status === 422 && !/reference does not exist/i.test(error.message)) {
        throw error;
      }
    }
    core.info(`Removed old CI release ${old.tag_name}`);
  }
};
