from pathlib import Path
import random
import json
from collections import defaultdict

# ====== 配置区 ======
ROOT = Path(".")               # 项目根目录
STIM_DIR = ROOT / "stimuli"    # 图片总目录

OUT_JSON = ROOT / "manifest_test.json"
OUT_JS = ROOT / "manifest_test.js"

IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"}

PER_FOLDER = 2                 # 每个文件夹抽几张
TOTAL = 10                     # 你想要的总张数（= folders_to_pick * PER_FOLDER）
RANDOM_SAMPLE = True           # True: 随机；False: 按排序取前几个
# ====================

def main():
    if not STIM_DIR.exists():
        raise FileNotFoundError(f"找不到目录：{STIM_DIR.resolve()}（确认脚本和 stimuli 同级？）")

    # 递归找所有图片
    all_imgs = [p for p in STIM_DIR.rglob("*") if p.is_file() and p.suffix.lower() in IMG_EXTS]
    if not all_imgs:
        raise RuntimeError(f"{STIM_DIR.resolve()} 下没有找到图片文件（检查后缀/路径）")

    # 1) 按“顶层子文件夹”分组：stimuli/<folder>/...
    #    如果你想按“图片所在的直接父文件夹”分组，把 folder_key 改成 p.parent.name
    groups = defaultdict(list)
    for p in all_imgs:
        rel_parts = p.relative_to(STIM_DIR).parts
        if len(rel_parts) == 0:
            continue
        folder_key = rel_parts[0]          # 顶层文件夹名
        groups[folder_key].append(p)

    folder_names = sorted(groups.keys())
    if not folder_names:
        raise RuntimeError("没有可用的文件夹分组（检查 stimuli 目录结构）")

    folders_needed = max(1, TOTAL // PER_FOLDER)
    folders_needed = min(folders_needed, len(folder_names))

    # 2) 选择要抽样的文件夹
    if RANDOM_SAMPLE:
        picked_folders = random.sample(folder_names, k=folders_needed)
    else:
        picked_folders = folder_names[:folders_needed]

    # 3) 每个文件夹抽 PER_FOLDER 张
    picked_imgs = []
    for fn in picked_folders:
        imgs = groups[fn]
        if not imgs:
            continue

        if RANDOM_SAMPLE:
            k = min(PER_FOLDER, len(imgs))
            picked_imgs.extend(random.sample(imgs, k=k))
        else:
            picked_imgs.extend(sorted(imgs)[:min(PER_FOLDER, len(imgs))])

    # 4) 如果因为某些文件夹图片不够导致总数不足，进行“补齐”（从剩余图片里补）
    if len(picked_imgs) < TOTAL:
        picked_set = set(picked_imgs)
        remaining = [p for p in all_imgs if p not in picked_set]
        need = TOTAL - len(picked_imgs)
        if remaining:
            if RANDOM_SAMPLE:
                picked_imgs.extend(random.sample(remaining, k=min(need, len(remaining))))
            else:
                picked_imgs.extend(sorted(remaining)[:min(need, len(remaining))])

    # 5) 生成 manifest
    manifest = []
    for p in picked_imgs[:TOTAL]:
        rel = p.relative_to(ROOT).as_posix()  # e.g. stimuli/ABPS_alcohol/xxx.jpg
        top_folder = p.relative_to(STIM_DIR).parts[0]
        manifest.append({
            "image": rel,
            "folder": top_folder
        })

    OUT_JSON.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    OUT_JS.write_text("const manifest = " + json.dumps(manifest, ensure_ascii=False, indent=2) + ";\n",
                      encoding="utf-8")

    print(f"✅ 找到图片总数: {len(all_imgs)}")
    print(f"✅ 文件夹数: {len(folder_names)} | 本次选中文件夹: {len(picked_folders)} | 每文件夹: {PER_FOLDER} 张")
    print(f"✅ 已输出(共 {len(manifest)} 张):")
    print(f"   - {OUT_JSON.resolve()}")
    print(f"   - {OUT_JS.resolve()}")

if __name__ == "__main__":
    main()
