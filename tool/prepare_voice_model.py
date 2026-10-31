#!/usr/bin/env python3
"""下载并校验离线语音模型（Paraformer-zh INT8）。

模型权重不入 git 仓库（单文件 227MB，超过 GitHub 100MB 限制）。
克隆仓库后、构建带语音的 APK 之前，先执行本脚本：

    python3 tool/prepare_voice_model.py

脚本会：
  1. 从 Hugging Face 镜像下载 model.int8.onnx 与 tokens.txt
  2. 校验文件大小与 SHA256（写死，防止被替换）
  3. 放入 assets/asr/

模型来自 FunASR / 阿里达摩院，ONNX 导出由 sherpa-onnx 提供。
"""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO = 'csukuangfj/sherpa-onnx-paraformer-zh-2024-03-09'
REVISION = '906992d326ebf0c5171cde675aa0902be9e5bc6c'
MIRRORS = [
    'https://huggingface.co/{repo}/resolve/{rev}/{name}',
    'https://hf-mirror.com/{repo}/resolve/{rev}/{name}',
]

# name -> (size, sha256)
FILES = {
    'model.int8.onnx': (
        227330205,
        '90bc03034ae1bef9575f8cc798cd1519c8be8aa9e8b458a033e32017ff4d584c',
    ),
    'tokens.txt': (
        75354,
        '6c0e3b35cece259829e6cb5b8d90d13db88f61ea3a2953d11898e4b2bfd7a2e2',
    ),
}

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'assets' / 'asr'
CACHE = ROOT / '.voice-model-cache'


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(block)
    return sha.hexdigest()


def download(name: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    target = CACHE / name
    size, sha = FILES[name]
    if target.exists() and target.stat().st_size == size and digest(target) == sha:
        print(f'  [cached] {name}')
        return target

    errors: list[str] = []
    for template in MIRRORS:
        url = template.format(repo=REPO, rev=REVISION, name=name)
        print(f'  下载 {name} ← {url}')
        tmp = target.with_suffix(target.suffix + '.part')
        try:
            if shutil.which('curl'):
                subprocess.run(
                    ['curl', '--fail', '--location', '--retry', '3',
                     '--connect-timeout', '30', '--max-time', '900',
                     '--progress-bar', '--output', str(tmp), url],
                    check=True,
                )
            else:
                with urllib.request.urlopen(url, timeout=120) as resp, tmp.open('wb') as out:
                    shutil.copyfileobj(resp, out)
            tmp.rename(target)
            break
        except Exception as exc:  # noqa: BLE001
            errors.append(f'{url}: {exc}')
            tmp.unlink(missing_ok=True)

    if not target.exists():
        raise RuntimeError('模型下载失败：\n  ' + '\n  '.join(errors))

    actual_size = target.stat().st_size
    actual_sha = digest(target)
    if actual_size != size or actual_sha != sha:
        target.unlink(missing_ok=True)
        raise RuntimeError(
            f'{name} 校验失败：size={actual_size} (期望 {size})，sha256={actual_sha} (期望 {sha})'
        )
    print(f'  [ok] {name} {actual_size / 1048576:.1f} MB')
    return target


def main() -> int:
    print('准备离线语音模型（Paraformer-zh INT8）…')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        src = download(name)
        shutil.copy2(src, OUTPUT / name)
    sample = CACHE / 'test_wavs/0.wav'
    sample.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['curl', '--fail', '-L', '--retry', '3', '--max-time', '120',
      '-o', str(sample), f'https://huggingface.co/{REPO}/resolve/{REVISION}/test_wavs/0.wav'], check=True)
    total = sum((OUTPUT / n).stat().st_size for n in FILES)
    print(f'完成：{OUTPUT} （{total / 1048576:.1f} MB）')
    print('现在可以执行：flutter build apk --release')
    return 0


if __name__ == '__main__':
    sys.exit(main())

