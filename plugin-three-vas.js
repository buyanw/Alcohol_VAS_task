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

      // Derive image folder (parent directory) and image file name from the stimulus path/URL.
      // Example stimulus: "images/food/img001.jpg" -> folder="food", file="img001.jpg"
      function deriveImageMeta(stimulus){
        try{
          const url = new URL(stimulus, window.location.href);
          const path = url.pathname; // strips query/hash
          const parts = path.split("/").filter(Boolean);
          const image_file = parts.length ? parts[parts.length - 1] : "";
          const image_folder = parts.length >= 2 ? parts[parts.length - 2] : "";
          return { image_folder, image_file };
        }catch(e){
          const path = String(stimulus || "").split("?")[0].split("#")[0];
          const parts = path.split(/[\/]/).filter(Boolean); // supports backslashes too
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
          canvas{ display:block; margin-top:${Math.round(10*s)}px; }
          button{
            margin-top:${Math.round(10*s)}px;
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

      const logicalW = Math.round(900 * s);
      const logicalH = Math.round(210 * s);
      const dpr = window.devicePixelRatio || 1;

      canvas.style.width = `${logicalW}px`;
      canvas.style.height = `${logicalH}px`;
      canvas.width = Math.round(logicalW * dpr);
      canvas.height = Math.round(logicalH * dpr);

      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      const padX = Math.round(90 * s);
      const x1 = padX;
      const x2 = logicalW - padX;

      const y1 = Math.round(45 * s);
      const y2 = Math.round(110 * s);
      const y3 = Math.round(175 * s);
      const ys = [y1, y2, y3];

      const q = [
        {title: trial.q1, l: trial.left_label_1, r: trial.right_label_1, key:"r1"},
        {title: trial.q2, l: trial.left_label_2, r: trial.right_label_2, key:"r2"},
        {title: trial.q3, l: trial.left_label_3, r: trial.right_label_3, key:"r3"},
      ];

      function draw() {
        ctx.clearRect(0,0,logicalW,logicalH);

        q.forEach((qq, i) => {
          const y = ys[i];

          ctx.fillStyle = "#fff";
          ctx.font = `${Math.round(16*s)}px Arial`;
          ctx.fillText(qq.title, 10, y - Math.round(12*s));

          ctx.strokeStyle = "#fff";
          ctx.lineWidth = Math.max(2, Math.round(2*s));
          ctx.beginPath();
          ctx.moveTo(x1, y);
          ctx.lineTo(x2, y);
          ctx.stroke();

          ctx.beginPath();
          ctx.moveTo(x1, y - Math.round(8*s));
          ctx.lineTo(x1, y + Math.round(8*s));
          ctx.moveTo(x2, y - Math.round(8*s));
          ctx.lineTo(x2, y + Math.round(8*s));
          ctx.stroke();

          ctx.font = `${Math.round(12*s)}px Arial`;
          ctx.fillText(qq.l, x1, y + Math.round(22*s));
          const w = ctx.measureText(qq.r).width;
          ctx.fillText(qq.r, x2 - w, y + Math.round(22*s));

          const val = ratings[qq.key];
          if (val !== null) {
            const x = x1 + (val/100)*(x2-x1);
            ctx.beginPath();
            ctx.arc(x, y, Math.round(6*s), 0, Math.PI*2);
            ctx.fill();
          }
        });

        btn.disabled = !(ratings.r1 !== null && ratings.r2 !== null && ratings.r3 !== null);
      }

      function whichLine(clickY) {
        const tol = Math.round(18*s);
        let best = -1, bestD = Infinity;
        for (let i=0;i<ys.length;i++){
          const d = Math.abs(clickY - ys[i]);
          if (d < bestD) { bestD = d; best = i; }
        }
        return bestD <= tol ? best : -1;
      }

      function xToRating(x) {
        const clamped = Math.max(x1, Math.min(x2, x));
        return Math.round(((clamped - x1)/(x2-x1))*100);
      }

      canvas.addEventListener("mousedown", (e) => {
        const rect = canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const idx = whichLine(y);
        if (idx === -1) return;
        ratings[q[idx].key] = xToRating(x);
        draw();
      });

      btn.addEventListener("click", () => {
        const rt = Math.round(performance.now() - start_time);
        // --- 关键修改在这里 ---
        this.jsPsych.finishTrial({
          // 添加一个明确的标记，表示这是一条有效的VAS数据
          is_vas_response: true, 


          // image meta extracted from stimulus path
          image_folder: deriveImageMeta(trial.stimulus).image_folder,
          image_file: deriveImageMeta(trial.stimulus).image_file,

          // identifiers
          image_id: trial.image_id,
          library: trial.library,
          stimulus: trial.stimulus,

          // VAS ratings (0-100)
          craving: ratings.r1,
          valence: ratings.r2,
          arousal: ratings.r3,

          // keep raw keys too (optional)
          // r1: ratings.r1, // 我注释掉了重复的键，使数据更整洁
          // r2: ratings.r2,
          // r3: ratings.r3,

          // reaction time (ms) from image onset to confirm
          rt: rt
        });
        // -----------------------
      });

      draw();
    }
  }

  window.jsPsychThreeVas = ThreeVas;
})();
