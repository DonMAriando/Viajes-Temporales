import {mkdir, readFile, writeFile} from "node:fs/promises";
import {resolve, dirname} from "node:path";
import {fileURLToPath} from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = resolve(root, ".asset_sources", "makehuman");
const rig = JSON.parse(await readFile(resolve(source, "rig.json"), "utf8"));
const weights = JSON.parse(await readFile(resolve(source, "weights.json"), "utf8")).weights;
const sub = (a, b) => a.map((v, i) => v - b[i]);
const add = (a, b) => a.map((v, i) => v + b[i]);
const length = a => Math.hypot(...a);
const normalize = a => a.map(v => v / (length(a) || 1));
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const scale = (a, factor) => a.map(v => v * factor);
const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
const smoothstep = t => {
  const value = Math.max(0, Math.min(1, t));
  return value * value * (3 - 2 * value);
};

function parseObj(text) {
  const vertices = [], uvs = [], faces = [], groups = new Map();
  let group = "";
  for (const line of text.split(/\r?\n/)) {
    const fields = line.trim().split(/\s+/);
    if (fields[0] === "v") vertices.push(fields.slice(1, 4).map(Number));
    if (fields[0] === "vt") uvs.push([Number(fields[1]), 1 - Number(fields[2])]);
    if (fields[0] === "g") {
      group = fields.slice(1).join(" ");
      if (!groups.has(group)) groups.set(group, new Set());
    }
    if (fields[0] === "f") {
      const face = fields.slice(1).map(v => {
        const [position, uv] = v.split("/");
        const index = Number(position) - 1;
        groups.get(group)?.add(index);
        return [index, Number(uv) - 1];
      });
      faces.push({group, vertices: face});
    }
  }
  return {vertices, uvs, faces, groups};
}

const human = parseObj(await readFile(resolve(source, "base.obj"), "utf8"));
const original = human.vertices.map(v => [...v]);
for (const line of (await readFile(resolve(source, "male.target"), "utf8")).split(/\r?\n/)) {
  if (!/^\d+\s/.test(line)) continue;
  const [index, x, y, z] = line.trim().split(/\s+/).map(Number);
  human.vertices[index] = add(human.vertices[index], [x, y, z]);
}
const bodyIndices = [...human.groups.get("body")];
const floor = Math.min(...bodyIndices.map(i => human.vertices[i][1]));
const transform = v => [v[0] * 0.1, (v[1] - floor) * 0.1, v[2] * 0.1];
human.vertices = human.vertices.map(transform);
const height = Math.max(...bodyIndices.map(i => human.vertices[i][1]));
const jointPosition = (name, vertices = human.vertices) => {
  const indices = rig.joints[name] ?? [...(human.groups.get(name) ?? [])];
  if (!indices.length) throw new Error(`Missing anatomical joint: ${name}`);
  return indices.reduce((a, i) => add(a, vertices[i]), [0, 0, 0]).map(v => v / indices.length);
};
const anatomicalBones = Object.keys(rig.bones);
const clothBones = ["cloth_front", "cloth_back"];
const boneNames = [...anatomicalBones, ...clothBones];
const boneIndex = new Map(boneNames.map((name, i) => [name, i]));
const boneParents = new Map(anatomicalBones.map(name => [name, rig.bones[name].parent]));
for (const name of clothBones) boneParents.set(name, "root");
const positions = [
  ...anatomicalBones.map(name => jointPosition(rig.bones[name].head)),
  ...clothBones.map(() => [0, height*0.59-0.035, 0.04])
];
const influences = new Map();
for (const [bone, values] of Object.entries(weights)) {
  if (!boneIndex.has(bone)) continue;
  for (const [vertex, weight] of values) {
    if (!influences.has(vertex)) influences.set(vertex, []);
    influences.get(vertex).push([boneIndex.get(bone), weight]);
  }
}
const skinCache = new Map();
function vertexWeights(index) {
  if (skinCache.has(index)) return skinCache.get(index);
  const values = [...(influences.get(index) ?? [[boneIndex.get("root"), 1]])].sort((a, b) => b[1]-a[1]).slice(0, 4);
  const total = values.reduce((sum, pair) => sum + pair[1], 0);
  while (values.length < 4) values.push([0, 0]);
  const skin = {joints: values.map(pair => pair[0]), weights: values.map(pair => pair[1] / total)};
  skinCache.set(index, skin);
  return skin;
}
function blendWeights(sources) {
  const combined = new Map();
  for (const [skin, factor] of sources) {
    for (let i = 0; i < 4; i++) {
      const weight = skin.weights[i] * factor;
      if (weight > 0) combined.set(skin.joints[i], (combined.get(skin.joints[i]) ?? 0) + weight);
    }
  }
  const values = [...combined].sort((a, b) => b[1] - a[1]).slice(0, 4);
  const total = values.reduce((sum, [, weight]) => sum + weight, 0);
  if (total <= 0) throw new Error("A garment vertex needs anatomical skinning weights.");
  while (values.length < 4) values.push([0, 0]);
  return {joints: values.map(([joint]) => joint), weights: values.map(([, weight]) => weight / total)};
}

function meshData() {
  return {positions: [], uvs: [], indices: [], joints: [], weights: []};
}
function pushVertex(mesh, position, uv, skin) {
  const index = mesh.positions.length / 3;
  mesh.positions.push(...position);
  mesh.uvs.push(...uv);
  mesh.joints.push(...skin.joints);
  mesh.weights.push(...skin.weights);
  return index;
}
function fromObj(obj, filter, skinning) {
  const mesh = meshData(), seen = new Map();
  for (const face of obj.faces) {
    if (!filter(face)) continue;
    const indices = face.vertices.map(([v, uv]) => {
      const id = `${v}/${uv}`;
      if (!seen.has(id)) seen.set(id, pushVertex(mesh, obj.vertices[v], obj.uvs[uv] ?? [0, 0], skinning(v)));
      return seen.get(id);
    });
    for (let i=1; i<indices.length-1; i++) mesh.indices.push(indices[0], indices[i], indices[i+1]);
  }
  return mesh;
}
const top = height * 0.59, bottom = height * 0.365;
const body = fromObj(human, face => face.group === "body", vertexWeights);
const clothingFaces = human.faces.filter(face => face.group === "body" &&
  face.vertices.every(([i]) => Math.abs(human.vertices[i][0]) < 0.3));
const cross2 = (a, b) => a[0] * b[1] - a[1] * b[0];

function bodySection(y, fitted=false) {
  const points = [], sections = [];
  for (const face of clothingFaces) {
    for (let triangle = 1; triangle < face.vertices.length - 1; triangle++) {
      const ids = [face.vertices[0][0], face.vertices[triangle][0], face.vertices[triangle + 1][0]];
      const cuts = [];
      for (let edge = 0; edge < 3; edge++) {
        const a = ids[edge], b = ids[(edge + 1) % 3];
        const p = human.vertices[a], q = human.vertices[b];
        if (!((p[1] <= y && q[1] > y) || (q[1] <= y && p[1] > y))) continue;
        const t = (y - p[1]) / (q[1] - p[1]);
        const cut = {
          point: [p[0] + (q[0] - p[0]) * t, p[2] + (q[2] - p[2]) * t],
          skin: blendWeights([[vertexWeights(a), 1 - t], [vertexWeights(b), t]])
        };
        points.push(cut);
        cuts.push(cut);
      }
      if (cuts.length === 2) sections.push(cuts);
    }
  }
  points.sort((a, b) => a.point[0] - b.point[0] || a.point[1] - b.point[1]);
  const unique = points.filter((p, i) => !i || length(sub(p.point, points[i - 1].point)) > 1e-7);
  const turn = (a, b, c) => cross2(sub(b.point, a.point), sub(c.point, a.point));
  const half = ordered => {
    const result = [];
    for (const point of ordered) {
      while (result.length > 1 && turn(result.at(-2), result.at(-1), point) <= 0) result.pop();
      result.push(point);
    }
    return result.slice(0, -1);
  };
  const hull = [...half(unique), ...half([...unique].reverse())];
  if (hull.length < 3) throw new Error(`No closed body section at garment height ${y}.`);
  const center = [0, (Math.min(...hull.map(p => p.point[1])) + Math.max(...hull.map(p => p.point[1]))) / 2];
  const edges = fitted ? sections : hull.map((a, i) => [a, hull[(i+1)%hull.length]]);
  return angle => {
    const direction = [Math.sin(angle), Math.cos(angle)];
    let result = null, furthest = 0;
    for (const [a, b] of edges) {
      const edge = sub(b.point, a.point), origin = sub(a.point, center);
      const determinant = cross2(direction, edge);
      if (Math.abs(determinant) < 1e-9) continue;
      const radius = cross2(origin, edge) / determinant;
      const t = cross2(origin, direction) / determinant;
      if (radius <= furthest || t < -1e-7 || t > 1 + 1e-7) continue;
      const factor = Math.max(0, Math.min(1, t));
      furthest = radius;
      result = {
        point: [direction[0] * radius, y, center[1] + direction[1] * radius],
        skin: blendWeights([[a.skin, 1 - factor], [b.skin, factor]])
      };
    }
    if (result) return result;
    throw new Error(`The garment contour is open at height ${y}, angle ${angle}.`);
  };
}

function garment(low, high, rings, segments, belt=false) {
  const mesh = meshData();
  for (let row=0; row<=rings; row++) {
    const y = low + (high-low)*row/rings;
    const section = bodySection(y, belt || y > top-0.07);
    const depth = 1 - row / rings;
    const flare = belt ? 0 : 0.04 * smoothstep(depth);
    const drape = belt ? 0 : smoothstep((top-0.055-y)/0.10);
    for (let col=0; col<=segments; col++) {
      const a = 2*Math.PI*col/segments;
      const contour = section(a);
      const fold = belt ? 0.001*Math.sin(a*28) :
        (0.002+depth*0.009)*Math.sin(a*18+depth*0.35)*smoothstep(depth/0.15);
      const offset = (belt ? 0.010 : 0.006+0.012*drape) + flare*(0.55+0.45*Math.abs(Math.sin(a))) + fold;
      const p = add(contour.point, [Math.sin(a)*offset, 0, Math.cos(a)*offset]);
      let skin = contour.skin;
      if (!belt) {
        // Separate hem controls keep the wrap outside the leading and trailing thighs.
        const front = Math.cos(a) >= 0;
        const center = Math.abs(Math.cos(a))**2;
        const leg = Math.sin(a) >= 0 ? "L" : "R";
        const cloth = {
          joints:[boneIndex.get(front ? "cloth_front" : "cloth_back"), boneIndex.get(`upperleg01.${leg}`), 0, 0],
          weights:[center, 1-center, 0, 0]
        };
        skin = blendWeights([[contour.skin, 1-drape], [cloth, drape]]);
      }
      pushVertex(mesh, p, [col/segments*2, row/rings*(belt ? 0.15 : 2)], skin);
    }
  }
  for (let row=0; row<rings; row++) for (let col=0; col<segments; col++) {
    const a=row*(segments+1)+col, b=a+1, d=a+segments+1, c=d+1;
    mesh.indices.push(a,b,d,b,c,d);
  }
  if (belt) {
    // The folded rim meets intact skin instead of leaving an open tube around the waist.
    for (const row of [0, rings]) {
      const y = row ? high : low, section = bodySection(y, true);
      const offset = mesh.positions.length / 3;
      for (let col = 0; col <= segments; col++) {
        const angle = col / segments * Math.PI * 2;
        const contour = section(angle), outer = row*(segments+1)+col;
        pushVertex(mesh, mesh.positions.slice(outer*3, outer*3+3), [col/segments*2, 0], contour.skin);
        pushVertex(mesh, add(contour.point, [-Math.sin(angle)*0.0008, 0, -Math.cos(angle)*0.0008]),
          [col/segments*2, 0.035], contour.skin);
      }
      for (let col = 0; col < segments; col++) {
        const a = offset+col*2, b = a+2, d = a+1, c = b+1;
        mesh.indices.push(...(row ? [a,b,d,b,c,d] : [a,d,b,b,d,c]));
      }
    }
  }
  return mesh;
}
const robe = garment(bottom, top, 52, 96);
const belt = garment(top-0.038, top+0.006, 4, 96, true);
const eyesObj = parseObj(await readFile(resolve(source, "eyes.obj"), "utf8"));
const headDelta = sub(jointPosition(rig.bones.head.head), transform(jointPosition(rig.bones.head.head, original)));
eyesObj.vertices = eyesObj.vertices.map(v => add(transform(v), headDelta));
const eyes = fromObj(eyesObj, () => true, index => ({
  joints:[boneIndex.get(eyesObj.vertices[index][0]>0 ? "eye.L" : "eye.R"),0,0,0], weights:[1,0,0,0]
}));
const sandals = meshData();
const soleBottom = -0.009;
for (const side of ["L","R"]) {
  const foot = positions[boneIndex.get(`foot.${side}`)];
  const skin={joints:[boneIndex.get(`foot.${side}`),0,0,0],weights:[1,0,0,0]};
  const offset=sandals.positions.length/3;
  for (let row=0; row<=1; row++) for (let col=0; col<=48; col++) {
    const a=col/48*Math.PI*2;
    pushVertex(sandals,[foot[0]+Math.sin(a)*0.054,soleBottom+row*0.014,foot[2]+0.055+Math.cos(a)*0.14],[col/48,row],skin);
  }
  for(let col=0;col<48;col++) sandals.indices.push(offset+col,offset+col+1,offset+col+49,offset+col+1,offset+col+50,offset+col+49);
  for (let row = 0; row <= 1; row++) {
    const center = pushVertex(sandals, [foot[0], soleBottom+row*0.014, foot[2]+0.055], [0.5,0.5], skin);
    for (let col = 0; col < 48; col++) {
      const a = offset+row*49+col, b = a+1;
      sandals.indices.push(...(row ? [center,a,b] : [center,b,a]));
    }
  }
}
const scar = meshData();
const leftEye = positions[boneIndex.get("eye.L")];
const scarX = leftEye[0] + 0.008, scarY = leftEye[1] + 0.039;
const brow = bodyIndices.filter(i => Math.abs(human.vertices[i][0]-scarX)<0.012 && Math.abs(human.vertices[i][1]-scarY)<0.014);
if (!brow.length) throw new Error("The eyebrow scar must lie on the anatomical face surface.");
const scarZ = Math.max(...brow.map(i => human.vertices[i][2])) + 0.002;
const scarSkin = {joints:[boneIndex.get("head"),0,0,0],weights:[1,0,0,0]};
for (const [x,y,u,v] of [[-0.004,-0.015,0,0],[0.001,-0.016,1,0],[0.007,0.017,1,1],[0.002,0.018,0,1]]) {
  pushVertex(scar,[scarX+x,scarY+y,scarZ],[u,v],scarSkin);
}
scar.indices.push(0,1,2,0,2,3);

function normals(mesh) {
  const result=new Array(mesh.positions.length).fill(0);
  for(let i=0;i<mesh.indices.length;i+=3) {
    const ids=mesh.indices.slice(i,i+3);
    const p=ids.map(index=>mesh.positions.slice(index*3,index*3+3));
    const n=cross(sub(p[1],p[0]),sub(p[2],p[0]));
    for(const index of ids) for(let j=0;j<3;j++) result[index*3+j]+=n[j];
  }
  for(let i=0;i<result.length;i+=3) result.splice(i,3,...normalize(result.slice(i,i+3)));
  return result;
}
function quaternion(x,y,z) {
  const cx=Math.cos(x/2),sx=Math.sin(x/2),cy=Math.cos(y/2),sy=Math.sin(y/2),cz=Math.cos(z/2),sz=Math.sin(z/2);
  return [sx*cy*cz-cx*sy*sz,cx*sy*cz+sx*cy*sz,cx*cy*sz-sx*sy*cz,cx*cy*cz+sx*sy*sz];
}
const inverseRotation = q => [-q[0], -q[1], -q[2], q[3]];
function multiplyRotations(a, b) {
  return [
    a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],
    a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],
    a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],
    a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]
  ];
}
function rotate(q, point) {
  const axis = q.slice(0, 3), t = scale(cross(axis, point), 2);
  return add(point, add(scale(t, q[3]), cross(axis, t)));
}
function rotationBetween(a, b) {
  const from = normalize(a), to = normalize(b);
  const q = [...cross(from, to), 1 + dot(from, to)];
  if (length(q) < 1e-6) throw new Error("A limb cannot reverse its anatomical direction.");
  return normalize(q);
}

const locomotion = {
  walk: {duration:1.08, stride:1.3, stance:0.62, lift:0.09, drop:0.095, bob:0.045, center:0, arm:0.25, heel:0.14, toe:0.35},
  run: {duration:0.64, stride:2.8, stance:0.34, lift:0.18, drop:0.13, bob:0.07, center:-0.06, arm:0.60, heel:0.08, toe:0.50}
};
function footPose(side, phase, gait) {
  const foot = positions[boneIndex.get(`foot.${side}`)];
  const hip = positions[boneIndex.get(`upperleg01.${side}`)];
  let z = 0, lift = 0, pitch = 0, lateral = 0;
  if (gait) {
    const span = gait.stride * gait.stance;
    if (phase < gait.stance) {
      const contact = phase / gait.stance;
      z = span * (0.5 - contact);
      pitch = -gait.heel*(1-smoothstep(contact/0.16)) + gait.toe*smoothstep((contact-0.65)/0.35);
    } else {
      const swing = (phase - gait.stance) / (1 - gait.stance);
      const t2 = swing*swing, t3 = t2*swing;
      const tangent = -gait.stride*(1-gait.stance);
      z = -span*0.5*(2*t3-3*t2+1) + span*0.5*(-2*t3+3*t2) +
        tangent*(2*t3-3*t2+swing);
      lift = gait.lift*Math.sin(Math.PI*swing);
      pitch = gait.toe*(1-smoothstep(swing))-gait.heel*smoothstep(swing)-0.18*Math.sin(Math.PI*swing);
      lateral = 0.01*Math.sin(Math.PI*swing);
    }
  }
  const rotation = quaternion(pitch, 0, 0);
  const contactOffset = pitch >= 0 ? 0.14 : -0.14;
  const pivot = [hip[0]+(side === "L" ? 1 : -1)*(0.036+lateral), lift, foot[2]+0.055+(gait ? gait.center : 0)+z+contactOffset];
  const sole = [0, soleBottom-foot[1], 0.055+contactOffset];
  return {position:sub(pivot, rotate(rotation, sole)), rotation};
}
function legPose(side, target, rootDelta, rootRotation) {
  const hip = positions[boneIndex.get(`upperleg01.${side}`)];
  const knee = positions[boneIndex.get(`lowerleg01.${side}`)];
  const ankle = positions[boneIndex.get(`foot.${side}`)];
  const rootPosition = positions[boneIndex.get("root")];
  const origin = add(add(rootPosition, rootDelta), rotate(rootRotation, sub(hip, rootPosition)));
  const upper = sub(knee, hip), lower = sub(ankle, knee);
  const a = length(upper), b = length(lower), delta = sub(target.position, origin), distance = length(delta);
  if (distance >= a+b-0.0002 || distance <= Math.abs(a-b)+0.0002) {
    throw new Error(`Unreachable ${side} foot target (${distance.toFixed(4)} m; leg ${(a+b).toFixed(4)} m).`);
  }
  const direction = normalize(delta);
  const pole = normalize(sub([0,0,1], scale(direction, direction[2])));
  const along = (a*a-b*b+distance*distance)/(2*distance);
  const bend = Math.sqrt(Math.max(0, a*a-along*along));
  const joint = add(origin, add(scale(direction, along), scale(pole, bend)));
  const upperRotation = rotationBetween(upper, sub(joint, origin));
  const lowerRotation = rotationBetween(lower, sub(target.position, joint));
  return {
    [`upperleg01.${side}`]:multiplyRotations(inverseRotation(rootRotation), upperRotation),
    [`lowerleg01.${side}`]:multiplyRotations(inverseRotation(upperRotation), lowerRotation),
    [`foot.${side}`]:multiplyRotations(inverseRotation(lowerRotation), target.rotation)
  };
}
function armPose(side, swing, flex) {
  const sign = side === "L" ? 1 : -1;
  const shoulder = positions[boneIndex.get(`upperarm01.${side}`)];
  const elbow = positions[boneIndex.get(`lowerarm01.${side}`)];
  const wrist = positions[boneIndex.get(`wrist.${side}`)];
  const upper = sub(elbow, shoulder), lower = sub(wrist, elbow);
  const upperDirection = scale(normalize([sign*0.12, -1, 0.02]), length(upper));
  const lowerDirection = scale(normalize([sign*0.05, -1, 0.01]), length(lower));
  const upperRotation = rotationBetween(upper, rotate(quaternion(swing,0,0), upperDirection));
  const lowerRotation = rotationBetween(lower, rotate(quaternion(swing+flex,0,0), lowerDirection));
  return {
    [`upperarm01.${side}`]:upperRotation,
    [`lowerarm01.${side}`]:multiplyRotations(inverseRotation(upperRotation), lowerRotation)
  };
}
function characterPose(action, progress) {
  const t = progress*Math.PI*2, gait = locomotion[action];
  const sway = gait ? (action === "run" ? 0.018 : 0.012)*Math.sin(t) : 0;
  const twist = gait ? (action === "run" ? 0.04 : 0.025)*Math.sin(t) : 0;
  const rootDelta = gait ? [0.008*Math.sin(t), -gait.drop+gait.bob*Math.sin(t)**2, 0] : [0,0.01+0.0015*Math.sin(t),0];
  const rootRotation = quaternion(0, twist, sway);
  const lean = action === "run" ? 0.14 : 0.018;
  const rotations = {
    root:rootRotation,
    spine05:quaternion(lean, 0, -sway*0.75),
    spine02:quaternion(0, -twist*1.5, 0),
    head:quaternion(action === "captured" ? 0.08+0.01*Math.sin(t) : -lean*0.45, 0, 0)
  };
  for (const side of ["L","R"]) {
    const phase = (progress+(side === "L" ? 0 : 0.5)) % 1;
    Object.assign(rotations, legPose(side, footPose(side, phase, gait), rootDelta, rootRotation));
    let arm = gait ? gait.arm*Math.cos(phase*Math.PI*2) : 0.015*Math.sin(t);
    let elbow = gait ? (action === "run" ? -0.9 : -0.18-0.05*Math.cos(phase*Math.PI*2)) : -0.14;
    if (action === "captured") {arm=-0.45; elbow=-1.1;}
    Object.assign(rotations, armPose(side, arm, elbow));
  }
  const thighAngles = ["L","R"].map(side => {
    const direction = sub(positions[boneIndex.get(`lowerleg01.${side}`)], positions[boneIndex.get(`upperleg01.${side}`)]);
    const posed = rotate(rotations[`upperleg01.${side}`], direction);
    return Math.atan2(posed[2], -posed[1]);
  });
  rotations.cloth_front = quaternion(-Math.max(0, ...thighAngles)-0.04, 0, 0);
  rotations.cloth_back = quaternion(-Math.min(0, ...thighAngles)+0.04, 0, 0);
  return {translation:add(positions[boneIndex.get("root")], rootDelta), rotations};
}

async function exportCharacter(name, skinName, tint) {
  const parts=[], views=[], accessors=[];
  let byteLength=0;
  const gltf={
    asset:{version:"2.0",generator:"MERIDIAN character pipeline; MakeHuman CC0 anatomical mesh"},
    scene:0,scenes:[{nodes:[0]}],nodes:[{name,children:[],extras:{
      walk_stride:locomotion.walk.stride, run_stride:locomotion.run.stride
    }}],meshes:[],skins:[],animations:[],
    materials:[],textures:[],images:[],samplers:[{magFilter:9729,minFilter:9987,wrapS:10497,wrapT:10497}]
  };
  function buffer(data, componentType, type, target, bounds=false) {
    const bytes=Buffer.from(data.buffer,data.byteOffset,data.byteLength);
    const view=views.length;
    views.push({buffer:0,byteOffset:byteLength,byteLength:bytes.length,...(target?{target}:{})});
    parts.push(bytes);
    const padding=(4-bytes.length%4)%4;
    if(padding) parts.push(Buffer.alloc(padding));
    byteLength+=bytes.length+padding;
    const size={SCALAR:1,VEC2:2,VEC3:3,VEC4:4,MAT4:16}[type];
    const entry={bufferView:view,componentType,count:data.length/size,type};
    if(bounds) {
      entry.min=Array(size).fill(Infinity);entry.max=Array(size).fill(-Infinity);
      for(let i=0;i<data.length;i++) {const axis=i%size;entry.min[axis]=Math.min(entry.min[axis],data[i]);entry.max[axis]=Math.max(entry.max[axis],data[i]);}
    }
    accessors.push(entry);
    return accessors.length-1;
  }
  const boneNodes=boneNames.map((bone,i)=>{
    const parent=boneParents.get(bone);
    const translation=parent?sub(positions[i],positions[boneIndex.get(parent)]):positions[i];
    const node=gltf.nodes.length;
    gltf.nodes.push({name:bone,translation,children:[]});
    return node;
  });
  for(let i=0;i<boneNames.length;i++) {
    const parent=boneParents.get(boneNames[i]);
    gltf.nodes[parent?boneNodes[boneIndex.get(parent)]:0].children.push(boneNodes[i]);
  }
  const inverse=positions.flatMap(p=>[1,0,0,0,0,1,0,0,0,0,1,0,-p[0],-p[1],-p[2],1]);
  gltf.skins.push({joints:boneNodes,skeleton:boneNodes[boneIndex.get("root")],inverseBindMatrices:buffer(new Float32Array(inverse),5126,"MAT4")});
  function texture(uri) {
    const i=gltf.images.length;gltf.images.push({uri});gltf.textures.push({sampler:0,source:i});return i;
  }
  const skin=texture(`../../textures/characters/${skinName}.png`);
  const eye=texture("../../textures/characters/brown_eye.png");
  const linen=texture("../../textures/linen/linen_undyed.png");
  const linenNormal=texture("../../textures/linen/textures/rough_linen_nor_gl_2k.jpg");
  const linenArm=texture("../../textures/linen/textures/rough_linen_arm_2k.jpg");
  gltf.materials.push(
    {name:"Skin",pbrMetallicRoughness:{baseColorTexture:{index:skin},metallicFactor:0,roughnessFactor:0.73}},
    {name:"Linen",doubleSided:true,pbrMetallicRoughness:{baseColorTexture:{index:linen},baseColorFactor:tint,metallicFactor:0,roughnessFactor:1,metallicRoughnessTexture:{index:linenArm}},normalTexture:{index:linenNormal,scale:0.45}},
    {name:"WovenBelt",doubleSided:true,pbrMetallicRoughness:{baseColorTexture:{index:linen},baseColorFactor:[0.35,0.24,0.13,1],metallicFactor:0,roughnessFactor:1}},
    {name:"Eyes",pbrMetallicRoughness:{baseColorTexture:{index:eye},metallicFactor:0,roughnessFactor:0.2}},
    {name:"Sandals",doubleSided:true,pbrMetallicRoughness:{baseColorFactor:[0.26,0.13,0.07,1],metallicFactor:0,roughnessFactor:0.9}},
    {name:"Scar",pbrMetallicRoughness:{baseColorFactor:[0.56,0.31,0.22,1],metallicFactor:0,roughnessFactor:0.8}}
  );
  const characterParts=[["Body",body,0],["Linen",robe,1],["Belt",belt,2],["Eyes",eyes,3],["Sandals",sandals,4]];
  if(name==="traveler") characterParts.push(["Scar",scar,5]);
  for(const [part,mesh,material] of characterParts) {
    const attributes={
      POSITION:buffer(new Float32Array(mesh.positions),5126,"VEC3",34962,true),
      NORMAL:buffer(new Float32Array(normals(mesh)),5126,"VEC3",34962),
      TEXCOORD_0:buffer(new Float32Array(mesh.uvs),5126,"VEC2",34962),
      JOINTS_0:buffer(new Uint16Array(mesh.joints),5123,"VEC4",34962),
      WEIGHTS_0:buffer(new Float32Array(mesh.weights),5126,"VEC4",34962)
    };
    const meshId=gltf.meshes.length;
    gltf.meshes.push({name:part,primitives:[{attributes,indices:buffer(new Uint32Array(mesh.indices),5125,"SCALAR",34963),material}]});
    gltf.nodes[0].children.push(gltf.nodes.length);gltf.nodes.push({name:part,mesh:meshId,skin:0});
  }
  const animated=["root","spine05","spine02","head","upperleg01.L","upperleg01.R","lowerleg01.L","lowerleg01.R","foot.L","foot.R","upperarm01.L","upperarm01.R","lowerarm01.L","lowerarm01.R",...clothBones];
  for(const animationName of ["idle","walk","run","captured"]) {
    const gait = locomotion[animationName], duration = gait?.duration ?? 3.2;
    const animation={name:animationName,channels:[],samplers:[],...(gait ? {extras:{stance_ratio:gait.stance}} : {})};
    const frames=Math.ceil(duration*60);
    const times=Array.from({length:frames+1},(_,i)=>duration*i/frames);
    const poses=times.map((_,i)=>characterPose(animationName,i/frames));
    const input=buffer(new Float32Array(times),5126,"SCALAR",undefined,true);
    const tracks=[{bone:"root",path:"translation"},...animated.map(bone=>({bone,path:"rotation"}))];
    for(const {bone,path} of tracks) {
      const values=poses.flatMap(pose=>path === "translation" ? pose.translation : pose.rotations[bone]);
      const output=buffer(new Float32Array(values),5126,path === "translation" ? "VEC3" : "VEC4");
      const sampler=animation.samplers.length;
      animation.samplers.push({input,output,interpolation:"LINEAR"});
      animation.channels.push({sampler,target:{node:boneNodes[boneIndex.get(bone)],path}});
    }
    gltf.animations.push(animation);
  }
  gltf.buffers=[{byteLength}];gltf.bufferViews=views;gltf.accessors=accessors;
  let json=Buffer.from(JSON.stringify(gltf));
  const padding=(4-json.length%4)%4;
  json=Buffer.concat([json,Buffer.alloc(padding,0x20)]);
  const binary=Buffer.concat(parts);
  const header=Buffer.alloc(12);header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(12+8+json.length+8+binary.length,8);
  const jsonHeader=Buffer.alloc(8);jsonHeader.writeUInt32LE(json.length);jsonHeader.writeUInt32LE(0x4e4f534a,4);
  const binaryHeader=Buffer.alloc(8);binaryHeader.writeUInt32LE(binary.length);binaryHeader.writeUInt32LE(0x004e4942,4);
  const destination=resolve(root,"assets","models","characters",`${name}.glb`);
  await mkdir(dirname(destination),{recursive:true});
  await writeFile(destination,Buffer.concat([header,jsonHeader,json,binaryHeader,binary]));
  console.log(`${name}: ${Math.round(height*100)} cm, ${boneNames.length} joints, ${Math.round(body.indices.length/3)} anatomical triangles, four skeletal animations.`);
}

await exportCharacter("egyptian","skin_dark",[1,0.94,0.81,1]);
await exportCharacter("traveler","skin_light",[0.58,0.52,0.4,1]);
