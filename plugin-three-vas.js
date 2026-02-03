// plugin-three-vas.js (jsPsych v8-compatible)
// Usage in timeline: { type: jsPsychThreeVas, stimulus: "...", ... }

(function () {
  const root = (typeof jsPsychModule !== "undefined") ? jsPsychModule : window.jsPsych;
  const PT = root.ParameterType;

  class ThreeVas {
    static info = {
      name: "three-vas",
      parameters: {
        stimulus: { type: PT.IMAGE, default: undefined },
        image_id: { type: PT.STRING, default: "" },
        library: { type: PT.STRING, default: "" },

        frame_width: { type: PT.INT, default: 1024 },
        frame_height: { type: PT.INT, default: 768 },
        image_box_width: { type: PT.INT, default: 900 },
        image_box_height: { type: PT.INT, default: 520 },

        q1: { type: PT.STRING, default: "Craving" },
        q2: { type: PT.STRING, default: "Valence" },
        q3: { type: PT.STRING, default: "Arousal" },

        left_label_1: { type: PT.STRING, default: "None" },
        right_label_1: { type: PT.STRING, default: "Strong" },
        left_label_2: { type: PT.STRING, default: "Unpleasant" },
        right_label_2: { type: PT.STRING, default: "Pleasant" },
        left_label_3: { type: PT.STRING, default: "Calm" },
        right_label_3: { type: PT.STRING, default: "Aroused" },

        scale: { type: PT.FLOAT, default: 1.0 },
        button_label: { type: PT.STRING, default: "Confirm" }
      }
    };

    constructor(jsPsych) {
      this.jsPsych = jsPsych;
    }

    trial(display_element, trial) {
      const start_time = performance.now();
      const s = trial.scale || 1.0;

      const ratings = { r1: null, r2: null, r3: null };
      const touched = { r1: false, r2: false, r3: false };

      // Derive image folder (parent directory) and image file name from the stimulus path/URL.
      function deriveImageMeta(stimulus){
        try{
          const url = new URL(stimulus, window.location.href);
          const path = url.pathname;
          const parts = path.split("/").filter(Boolean);
          const image_file = parts.length ? parts[parts.length - 1] : "";
          const image_folder = parts.length >= 2 ? parts[parts.length - 2] : "";
          return { image_folder, image_file };
        }catch(e){
          const path = String(stimulus || "").split("?")[0].split("#")[0];
          const parts = path.split(/[\/]/).filter(Boolean);
          const image_file = parts.length ? parts[parts.length - 1] : "";
          const image_folder = parts.length >= 2 ? parts[parts.length - 2] : "";
          return { image_folder, image_file };
        }
      }

      display_element.innerHTML = `
        <style>
          body { background:#000; margin:0; }
          .wrap{
            width:${Math.round(trial.frame_width*s)}px;
            height:${Math.round(trial.frame_height*s)}px;
            margin:0 auto;
            display:flex; flex-direction:column;
            align-items:center;
            color:#fff;
            font-family:Arial, sans-serif;
            user-select:none;
          }
          .imgbox{
            width:${Math.round(trial.image_box_width*s)}px;
            height:${Math.round(trial.image_box_height*s)}px;
            background:#000;
            display:flex; align-items:center; justify-content:center;
            margin-top:${Math.round(20*s)}px;
          }
          .imgbox img{ width:100%; height:100%; object-fit:contain; }

          /* 让三条bar整体更靠上：canvas上边距变小 */
          canvas{
            display:block;
            margin-top:${Math.round(4*s)}px;
            cursor:pointer;
            touch-action:none; /* pointer事件 + 触控拖动更稳 */
          }

          button{
            margin-top:${Math.round(8*s)}px;
            font-size:${Math.round(18*s)}px;
            padding:${Math.round(8*s)}px ${Math.round(18*s)}px;
            border-radius:${Math.round(10*s)}px;
            border:0;
            cursor:pointer;
          }
          button:disabled{ opacity:0.4; cursor:not-allowed; }
        </style>

        <div class="wrap">
          <div class="imgbox"><img src="${trial.stimulus}"></div>
          <canvas id="vasCanvas"></canvas>
          <button id="confirmBtn" disabled>${trial.button_label}</button>
        </div>
      `;

      const canvas = display_element.querySelector("#vasCanvas");
      const btn = display_element.querySelector("#confirmBtn");

      // ===== 尺寸：略微紧凑，让bar“往上”并减少空白 =====
      const logicalW = Math.round(900 * s);
      const logicalH = Math.round(130* s);

      const dpr = window.devicePixelRatio || 1;
      canvas.style.width = `${logicalW}px`;
      canvas.style.height = `${logicalH}px`;
      canvas.width = Math.round(logicalW * dpr);
      canvas.height = Math.round(logicalH * dpr);

      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      // ===== bar变短：加大左右 padding =====
      const padX = Math.round(140 * s);  // 原来 90*s；变大 => bar 变短
      const x1 = padX;
      const x2 = logicalW - padX;

      // ===== 三条bar在canvas里稍微上移：用更紧凑的y布局 =====
      const yStart = Math.round(20 * s);
      const yGap   = Math.round(45 * s);
      const ys = [yStart, yStart + yGap, yStart + 2*yGap];

      const q = [
        {title: trial.q1, l: trial.left_label_1, r: trial.right_label_1, key:"r1"},
        {title: trial.q2, l: trial.left_label_2, r: trial.right_label_2, key:"r2"},
        {title: trial.q3, l: trial.left_label_3, r: trial.right_label_3, key:"r3"},
      ];

      // 命中范围（不点在线上也能识别）：加大容差
      const HIT_TOL = Math.round(26 * s);   // 原来 ~18*s
      const LABEL_GAP = Math.round(12 * s); // 标签离端点的距离

      function draw() {
        ctx.clearRect(0,0,logicalW,logicalH);

        q.forEach((qq, i) => {
          const y = ys[i];

          // title（保留在bar上方）
          ctx.fillStyle = "#fff";
          ctx.font = `${Math.round(16*s)}px Arial`;
          ctx.textAlign = "left";
          ctx.textBaseline = "alphabetic";
          ctx.fillText(qq.title, 10, y );

          // main line
          ctx.strokeStyle = "#fff";
          ctx.lineWidth = Math.max(2, Math.round(2*s));
          ctx.beginPath();
          ctx.moveTo(x1, y);
          ctx.lineTo(x2, y);
          ctx.stroke();

          // end ticks
          ctx.beginPath();
          ctx.moveTo(x1, y - Math.round(8*s));
          ctx.lineTo(x1, y + Math.round(8*s));
          ctx.moveTo(x2, y - Math.round(8*s));
          ctx.lineTo(x2, y + Math.round(8*s));
          ctx.stroke();

          // labels moved to BOTH SIDES of the bar (left/right of endpoints)
          ctx.font = `${Math.round(12*s)}px Arial`;
          ctx.textBaseline = "middle";

          ctx.textAlign = "right";
          ctx.fillText(qq.l, x1 - LABEL_GAP, y);

          ctx.textAlign = "left";
          ctx.fillText(qq.r, x2 + LABEL_GAP, y);

          // thumb
        const val = ratings[qq.key];

// 默认显示：如果没作答，就显示在 50%
        const shownVal = (val === null) ? 50 : val;
        const x = x1 + (shownVal/100) * (x2 - x1);

// 画点：未作答时画“空心点”，作答后画“实心点”
        ctx.beginPath();
        ctx.arc(x, y, Math.round(6*s), 0, Math.PI*2);

        if (val === null) {
            ctx.strokeStyle = "#fff";
            ctx.lineWidth = Math.max(2, Math.round(2*s));
            ctx.stroke();
        } else {
            ctx.fillStyle = "#fff";
            ctx.fill();
    }

        });

        btn.disabled = !(touched.r1 && touched.r2 && touched.r3);
        }

      function whichLine(pointerY) {
        let best = -1, bestD = Infinity;
        for (let i=0;i<ys.length;i++){
          const d = Math.abs(pointerY - ys[i]);
          if (d < bestD) { bestD = d; best = i; }
        }
        return bestD <= HIT_TOL ? best : -1;
      }

      function xToRating(x) {
        const clamped = Math.max(x1, Math.min(x2, x));
        return Math.round(((clamped - x1)/(x2-x1))*100);
      }

      // ===== 更大的点击/拖动范围：pointerdown + pointermove（按住拖动） =====
      let dragging = false;
      let dragIdx = -1;

      function getCanvasXY(e){
        const rect = canvas.getBoundingClientRect();
        return { x: e.clientX - rect.left, y: e.clientY - rect.top };
      }

      function setRatingByPointer(e, idx){
        const { x } = getCanvasXY(e);
        const k = q[idx].key;
        ratings[k] = xToRating(x);
        touched[k] = true;
        draw();

      }

      canvas.addEventListener("pointerdown", (e) => {
        const { y } = getCanvasXY(e);
        const idx = whichLine(y);
        if (idx === -1) return;

        dragging = true;
        dragIdx = idx;

        canvas.setPointerCapture?.(e.pointerId);
        setRatingByPointer(e, idx);
      });

      canvas.addEventListener("pointermove", (e) => {
        if (!dragging || dragIdx === -1) return;
        // 拖动时不需要一直“对准线”，只要在按住状态就更新同一条
        setRatingByPointer(e, dragIdx);
      });

      function endDrag(){
        dragging = false;
        dragIdx = -1;
      }
      canvas.addEventListener("pointerup", endDrag);
      canvas.addEventListener("pointercancel", endDrag);
      canvas.addEventListener("pointerleave", () => { /* 不强制结束，避免capture时跳 */ });

      btn.addEventListener("click", () => {
        const rt = Math.round(performance.now() - start_time);
        this.jsPsych.finishTrial({
          is_vas_response: true,

          image_folder: deriveImageMeta(trial.stimulus).image_folder,
          image_file: deriveImageMeta(trial.stimulus).image_file,

          image_id: trial.image_id,
          library: trial.library,
          stimulus: trial.stimulus,

          craving: ratings.r1,
          valence: ratings.r2,
          arousal: ratings.r3,

          rt: rt
        });
      });

      draw();
    }
  }

  window.jsPsychThreeVas = ThreeVas;
})();
