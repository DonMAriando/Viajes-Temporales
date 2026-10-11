import assert from "node:assert/strict";
import {readFile} from "node:fs/promises";
import {test} from "node:test";

const add = (a, b) => a.map((v, i) => v + b[i]);
const sub = (a, b) => a.map((v, i) => v - b[i]);
const scale = (a, s) => a.map(v => v * s);
const dot = (a, b) => a.reduce((sum, v, i) => sum + v * b[i], 0);
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const distance = (a, b) => Math.hypot(...sub(a, b));
function rotate(q, p) {
  const axis = q.slice(0, 3), t = scale(cross(axis, p), 2);
  return add(p, add(scale(t, q[3]), cross(axis, t)));
}
function multiply(a, b) {
  return [
    a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],
    a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],
    a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],
    a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]
  ];
}
function segmentDistance(p, a, b) {
  const edge = sub(b, a);
  const size = dot(edge, edge);
  if (size < 1e-16) return distance(p, a);
  const t = Math.max(0, Math.min(1, dot(sub(p, a), edge) / size));
  return distance(p, add(a, scale(edge, t)));
}
function triangleDistance(p, a, b, c) {
  const normal = cross(sub(b, a), sub(c, a)), size = dot(normal, normal);
  if (size > 1e-16) {
    const factor = dot(sub(p, a), normal) / size;
    const projected = sub(p, scale(normal, factor));
    if ([[a,b],[b,c],[c,a]].every(([v,w]) => dot(cross(sub(w,v), sub(projected,v)), normal) >= -1e-12)) {
      return Math.abs(factor) * Math.sqrt(size);
    }
  }
  return Math.min(segmentDistance(p,a,b), segmentDistance(p,b,c), segmentDistance(p,c,a));
}
function rayDistance(p, direction, a, b, c) {
  const edge = sub(b,a), other = sub(c,a), h = cross(direction,other);
  const determinant = dot(edge,h);
  if (Math.abs(determinant) < 1e-10) return null;
  const from = sub(p,a), u = dot(from,h)/determinant;
  if (u < 0 || u > 1) return null;
  const q = cross(from,edge), v = dot(direction,q)/determinant;
  if (v < 0 || u+v > 1) return null;
  const t = dot(other,q)/determinant;
  return t > 1e-7 ? t : null;
}

async function loadCharacter(name) {
  const data = await readFile(new URL(`../assets/models/characters/${name}.glb`, import.meta.url));
  assert.equal(data.readUInt32LE(0), 0x46546c67);
  const jsonLength = data.readUInt32LE(12);
  const gltf = JSON.parse(data.subarray(20, 20+jsonLength));
  const binary = data.subarray(28+jsonLength);
  const parents = new Map();
  gltf.nodes.forEach((node, i) => (node.children ?? []).forEach(child => parents.set(child, i)));
  function accessor(index) {
    const a = gltf.accessors[index], view = gltf.bufferViews[a.bufferView];
    const Type = {5123:Uint16Array, 5125:Uint32Array, 5126:Float32Array}[a.componentType];
    const width = {SCALAR:1, VEC2:2, VEC3:3, VEC4:4, MAT4:16}[a.type];
    assert.ok(Type && width, "Supported GLB accessor");
    return new Type(binary.buffer, binary.byteOffset+(view.byteOffset ?? 0)+(a.byteOffset ?? 0), a.count*width);
  }
  function transforms(animation, frame = 0) {
    const overrides = new Map(), result = new Map();
    for (const channel of animation?.channels ?? []) {
      const output = accessor(animation.samplers[channel.sampler].output);
      const width = channel.target.path === "rotation" ? 4 : 3;
      if (!overrides.has(channel.target.node)) overrides.set(channel.target.node, {});
      overrides.get(channel.target.node)[channel.target.path] = Array.from(output.slice(frame*width, (frame+1)*width));
    }
    function visit(index) {
      if (result.has(index)) return result.get(index);
      const node = {...gltf.nodes[index], ...overrides.get(index)};
      const local = {position:node.translation ?? [0,0,0], rotation:node.rotation ?? [0,0,0,1]};
      const parent = parents.has(index) ? visit(parents.get(index)) : null;
      const transform = parent ? {
        position:add(parent.position, rotate(parent.rotation, local.position)),
        rotation:multiply(parent.rotation, local.rotation)
      } : local;
      result.set(index, transform);
      return transform;
    }
    gltf.nodes.forEach((_, i) => visit(i));
    return result;
  }
  const rest = transforms(), joints = gltf.skins[0].joints;
  const bone = name => gltf.nodes.findIndex(node => node.name === name);
  const mesh = name => {
    const primitive = gltf.meshes.find(mesh => mesh.name === name).primitives[0];
    return {
      positions:accessor(primitive.attributes.POSITION), joints:accessor(primitive.attributes.JOINTS_0),
      weights:accessor(primitive.attributes.WEIGHTS_0), indices:accessor(primitive.indices)
    };
  };
  function skinVertex(mesh, vertex, pose) {
    const p = Array.from(mesh.positions.slice(vertex*3, vertex*3+3));
    let result = [0,0,0];
    for (let i = 0; i < 4; i++) {
      const joint = joints[mesh.joints[vertex*4+i]], transform = pose.get(joint);
      const bound = sub(p, rest.get(joint).position);
      result = add(result, scale(add(transform.position, rotate(transform.rotation, bound)), mesh.weights[vertex*4+i]));
    }
    return result;
  }
  return {gltf, accessor, transforms, rest, bone, mesh, skinVertex};
}

for (const name of ["egyptian", "traveler"]) {
  const character = await loadCharacter(name);
  const {gltf, accessor, transforms, rest, bone, mesh, skinVertex} = character;

  test(`${name}: intact skin and fitted, closed waistband in every animation`, () => {
    const body = mesh("Body"), belt = mesh("Belt");
    const low = Math.min(...belt.positions.filter((_, i) => i % 3 === 1));
    const high = Math.max(...belt.positions.filter((_, i) => i % 3 === 1));
    const triangles = [];
    for (let i = 0; i < body.indices.length; i += 3) {
      const ids = Array.from(body.indices.slice(i, i+3));
      const ys = ids.map(v => body.positions[v*3+1]);
      if (Math.min(...ys) < high+0.025 && Math.max(...ys) > low-0.025 &&
          ids.every(v => Math.abs(body.positions[v*3]) < 0.3)) triangles.push(ids);
    }
    assert.ok(body.positions.some((v,i) => i % 3 === 1 && v > 0.85 && v < 0.95 &&
      Math.abs(body.positions[i-1]) < 0.15 && Math.abs(body.positions[i+1]) < 0.2),
      "The pelvis remains underneath the clothing");
    const outerCount = 5*97, rimCount = 2*97;
    assert.equal(belt.positions.length/3, outerCount+rimCount*2, "Both waistband rims are capped");
    let largestGap = 0, worstPose = "";
    for (const animation of gltf.animations) {
      const count = gltf.accessors[animation.samplers[0].input].count;
      for (let frame = 0; frame < count; frame += Math.max(1, Math.floor(count/12))) {
        const pose = transforms(animation, frame);
        const vertices = new Map();
        for (const ids of triangles) for (const v of ids) {
          if (!vertices.has(v)) vertices.set(v, skinVertex(body,v,pose));
        }
        for (const rim of [outerCount, outerCount+rimCount]) {
          for (let col = 0; col < 96; col += 4) {
            const p = skinVertex(belt, rim+col*2+1, pose);
            const gap = Math.min(...triangles.map(ids => triangleDistance(p, ...ids.map(v => vertices.get(v)))));
            if (gap > largestGap) {
              largestGap = gap;
              worstPose = `${animation.name}, frame ${frame}, rim ${rim}, column ${col}`;
            }
          }
        }
      }
    }
    assert.ok(largestGap < 0.002, `Waistband-to-skin distance ${largestGap.toFixed(5)} m exceeds 2 mm (${worstPose})`);
  });

  for (const action of ["walk", "run"]) {
    test(`${name}: hips and thighs do not cut through the fabric during ${action}`, () => {
      const body = mesh("Body"), cloth = mesh("Linen");
      const covered = [];
      for (let i = 0; i < body.positions.length/3; i++) {
        const [x,y] = body.positions.slice(i*3,i*3+3);
        if (Math.abs(x) < 0.23 && y > 0.88 && y < 0.995) covered.push(i);
      }
      assert.ok(covered.length > 32);
      const samples = covered.filter((_,i) => i % Math.ceil(covered.length/32) === 0);
      const animation = gltf.animations.find(a => a.name === action);
      const count = gltf.accessors[animation.samplers[0].input].count;
      const direction = [1,0.137,0.071];
      for (let frame = 0; frame < count; frame++) {
        const pose = transforms(animation,frame);
        const vertices = Array.from({length:cloth.positions.length/3}, (_,v) => skinVertex(cloth,v,pose));
        const triangles = [];
        for (let i = 0; i < cloth.indices.length; i += 3) {
          triangles.push(Array.from(cloth.indices.slice(i,i+3), v => vertices[v]));
        }
        // Caps are only for containment; a leg below the open hem is not fabric clipping.
        for (const start of [0,52*97]) {
          for (let col = 1; col < 96; col++) triangles.push([vertices[start],vertices[start+col],vertices[start+col+1]]);
        }
        for (const vertex of samples) {
          const p = skinVertex(body,vertex,pose);
          const hits = triangles.map(triangle => rayDistance(p,direction,...triangle)).filter(t => t !== null).sort((a,b)=>a-b);
          const unique = hits.filter((t,i) => !i || t-hits[i-1] > 1e-6);
          if (unique.length % 2 === 0) {
            const distances = triangles.map(triangle => triangleDistance(p,...triangle));
            const nearest = distances.indexOf(Math.min(...distances));
            const hem = cloth.indices.length/3;
            assert.ok(nearest >= hem && nearest < hem+95,
              `Body vertex ${vertex} cuts through the fabric in ${action}, frame ${frame}; boundary ${nearest}, distance ${distances[nearest].toFixed(5)} m`);
          }
        }
      }
    });

    test(`${name}: ${action} plants feet without sliding and clears the floor`, () => {
      const animation = gltf.animations.find(a => a.name === action);
      const times = accessor(animation.samplers[0].input), duration = times.at(-1);
      const stride = gltf.nodes[0].extras[`${action}_stride`], stance = animation.extras.stance_ratio;
      assert.ok(stride > 0 && stance > 0 && stance < 1);
      const sandals = mesh("Sandals");
      let clearance = 0, minimumHeight = Infinity;
      const contacts = {L:[], R:[]};
      const first = transforms(animation,0), last = transforms(animation,times.length-1);
      for (const side of ["L","R"]) {
        for (const limb of ["foot","wrist"]) {
          assert.ok(distance(first.get(bone(`${limb}.${side}`)).position, last.get(bone(`${limb}.${side}`)).position) < 1e-6,
            "The gait loops without a pose jump");
        }
      }
      for (const frame of [0,Math.round((times.length-1)/2)]) {
        const pose = transforms(animation,frame);
        const armSwing = pose.get(bone("wrist.L")).position[2]-pose.get(bone("wrist.R")).position[2];
        const footSwing = pose.get(bone("foot.L")).position[2]-pose.get(bone("foot.R")).position[2];
        assert.ok(armSwing*footSwing < -0.001, "The arms counterbalance the opposite stepping leg");
      }
      for (let frame = 0; frame < times.length; frame++) {
        const progress = times[frame]/duration, pose = transforms(animation,frame);
        for (const side of ["L","R"]) {
          const foot = bone(`foot.${side}`), joint = pose.get(foot), bound = rest.get(foot).position;
          const center = add(joint.position, rotate(joint.rotation, [0,-0.009-bound[1],0.055]));
          const phase = (progress+(side === "L" ? 0 : 0.5)) % 1;
          if (phase > stance*0.2 && phase < stance*0.6) {
            contacts[side].push([center[0], center[1], center[2]+stride*progress]);
            assert.ok(Math.abs(center[1]) < 0.0005, "The supporting sole rests on the floor");
          }
        }
        let lowest = Infinity;
        for (let vertex = 0; vertex < sandals.positions.length/3; vertex++) {
          lowest = Math.min(lowest, skinVertex(sandals,vertex,pose)[1]);
        }
        minimumHeight = Math.min(minimumHeight, lowest);
        for (const side of ["L","R"]) {
          const offset = side === "L" ? 0 : 100;
          const height = Math.min(...Array.from({length:100}, (_,v) => skinVertex(sandals,v+offset,pose)[1]));
          clearance = Math.max(clearance, height);
        }
      }
      for (const side of ["L","R"]) {
        assert.ok(contacts[side].length >= 3, "The stance phase has several measured samples");
        const reference = contacts[side][0];
        const drift = Math.max(...contacts[side].map(p => distance(p,reference)));
        assert.ok(drift < 0.001, `The planted ${side} foot slides ${drift.toFixed(5)} m`);
      }
      assert.ok(minimumHeight >= -0.0005, `The sole intersects the floor by ${(-minimumHeight).toFixed(5)} m`);
      assert.ok(clearance > (action === "run" ? 0.15 : 0.07), `Swing clearance is only ${clearance.toFixed(5)} m`);
    });
  }
}
