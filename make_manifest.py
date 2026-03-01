# generate_manifest.py
from pathlib import Path
import json

# 你可以按需改：如果 stimuli 不在当前目录下，改成 Path("你的路径/stimuli")
STIMULI_DIR = Path("stimuli")

# 常见图片后缀（不区分大小写）
IMG_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"}

def to_posix_relpath(p: Path, base: Path) -> str:
    """把路径转成相对 base 的 web 路径（用 /）"""
    return p.relative_to(base).as_posix()

def main():
    if not STIMULI_DIR.exists():
        raise FileNotFoundError(f"Cannot find folder: {STIMULI_DIR.resolve()}")

    manifest = []

    # 只按 stimuli 下的“第一层子文件夹”作为类别
    for folder in sorted([p for p in STIMULI_DIR.iterdir() if p.is_dir()]):
        category = folder.name

        # 递归搜这个类别文件夹下的所有图片
        images = []
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix.lower() in IMG_EXTS:
                images.append(p)

        # 排序保证每次生成结果一致
        for img_path in sorted(images):
            manifest.append({
                "image": to_posix_relpath(img_path, Path(".")),  # 例如 stimuli/ABPS_alcohol/001.jpg
                "category": category
            })

    # 输出 JSON
    out_json = Path("manifest.json")
    out_json.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✅ Wrote {out_json} with {len(manifest)} images")

    # （可选）同时输出 JS 版本，方便你直接在 HTML 里引用
    out_js = Path("manifest.js")
    out_js.write_text("const manifest = " + json.dumps(manifest, ensure_ascii=False, indent=2) + ";\n", encoding="utf-8")
    print(f"✅ Wrote {out_js}")

if __name__ == "__main__":
    main()
