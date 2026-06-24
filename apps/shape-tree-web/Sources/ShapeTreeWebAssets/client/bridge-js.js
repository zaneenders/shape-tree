// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

export async function createInstantiator(options, swift) {
    let instance;
    let memory;
    let setException;
    let decodeString;
    const textDecoder = new TextDecoder("utf-8");
    const textEncoder = new TextEncoder("utf-8");
    let tmpRetString;
    let tmpRetBytes;
    let tmpRetException;
    let tmpRetOptionalBool;
    let tmpRetOptionalInt;
    let tmpRetOptionalFloat;
    let tmpRetOptionalDouble;
    let tmpRetOptionalHeapObject;
    let strStack = [];
    let i32Stack = [];
    let i64Stack = [];
    let f32Stack = [];
    let f64Stack = [];
    let ptrStack = [];
    let taStack = [];
    const enumHelpers = {};
    const structHelpers = {};

    let _exports = null;
    let bjs = null;
    const swiftClosureRegistry = (typeof FinalizationRegistry === "undefined") ? { register: () => {}, unregister: () => {} } : new FinalizationRegistry((state) => {
        if (state.unregistered) { return; }
        instance?.exports?.bjs_release_swift_closure(state.pointer);
    });
    const makeClosure = (pointer, file, line, func) => {
        const state = { pointer, file, line, unregistered: false };
        const real = (...args) => {
            if (state.unregistered) {
                const bytes = new Uint8Array(memory.buffer, state.file >>> 0);
                let length = 0;
                while (bytes[length] !== 0) { length += 1; }
                const fileID = decodeString(state.file, length);
                throw new Error(`Attempted to call a released JSTypedClosure created at ${fileID}:${state.line}`);
            }
            return func(...args);
        };
        real.__unregister = () => {
            if (state.unregistered) { return; }
            state.unregistered = true;
            swiftClosureRegistry.unregister(state);
        };
        swiftClosureRegistry.register(real, state, state);
        return swift.memory.retain(real);
    };

    const __bjs_createPageMessageHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.kind);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            const isSome = value.path != null ? 1 : 0;
            if (isSome) {
                const bytes1 = textEncoder.encode(value.path);
                const id1 = swift.memory.retain(bytes1);
                i32Stack.push(bytes1.length);
                i32Stack.push(id1);
            }
            i32Stack.push(isSome);
            const isSome1 = value.payload != null ? 1 : 0;
            if (isSome1) {
                const bytes2 = textEncoder.encode(value.payload);
                const id2 = swift.memory.retain(bytes2);
                i32Stack.push(bytes2.length);
                i32Stack.push(id2);
            }
            i32Stack.push(isSome1);
        },
        lift: () => {
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const string = strStack.pop();
                optValue = string;
            }
            const isSome1 = i32Stack.pop();
            let optValue1;
            if (isSome1 === 0) {
                optValue1 = null;
            } else {
                const string1 = strStack.pop();
                optValue1 = string1;
            }
            const string2 = strStack.pop();
            return { kind: string2, path: optValue1, payload: optValue };
        }
    });
    const __bjs_createShellMessageHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.kind);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            const isSome = value.payload != null ? 1 : 0;
            if (isSome) {
                const bytes1 = textEncoder.encode(value.payload);
                const id1 = swift.memory.retain(bytes1);
                i32Stack.push(bytes1.length);
                i32Stack.push(id1);
            }
            i32Stack.push(isSome);
        },
        lift: () => {
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const string = strStack.pop();
                optValue = string;
            }
            const string1 = strStack.pop();
            return { kind: string1, payload: optValue };
        }
    });
    const __bjs_createNavContentItemHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.path);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            const bytes1 = textEncoder.encode(value.slug);
            const id1 = swift.memory.retain(bytes1);
            i32Stack.push(bytes1.length);
            i32Stack.push(id1);
            const bytes2 = textEncoder.encode(value.title);
            const id2 = swift.memory.retain(bytes2);
            i32Stack.push(bytes2.length);
            i32Stack.push(id2);
            const bytes3 = textEncoder.encode(value.href);
            const id3 = swift.memory.retain(bytes3);
            i32Stack.push(bytes3.length);
            i32Stack.push(id3);
            i32Stack.push(value.hasWasm ? 1 : 0);
        },
        lift: () => {
            const bool = i32Stack.pop() !== 0;
            const string = strStack.pop();
            const string1 = strStack.pop();
            const string2 = strStack.pop();
            const string3 = strStack.pop();
            return { path: string3, slug: string2, title: string1, href: string, hasWasm: bool };
        }
    });
    const __bjs_createNavSignInActionHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.href);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            const bytes1 = textEncoder.encode(value.label);
            const id1 = swift.memory.retain(bytes1);
            i32Stack.push(bytes1.length);
            i32Stack.push(id1);
            i32Stack.push(value.spa ? 1 : 0);
        },
        lift: () => {
            const bool = i32Stack.pop() !== 0;
            const string = strStack.pop();
            const string1 = strStack.pop();
            return { href: string1, label: string, spa: bool };
        }
    });
    const __bjs_createNavContentGroupHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.label);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            const isSome = value.directory != null ? 1 : 0;
            if (isSome) {
                const bytes1 = textEncoder.encode(value.directory);
                const id1 = swift.memory.retain(bytes1);
                i32Stack.push(bytes1.length);
                i32Stack.push(id1);
            }
            i32Stack.push(isSome);
            for (const elem of value.items) {
                structHelpers.NavContentItem.lower(elem);
            }
            i32Stack.push(value.items.length);
        },
        lift: () => {
            const arrayLen = i32Stack.pop();
            let arrayResult;
            if (arrayLen === -1) {
                arrayResult = taStack.pop();
            } else {
                arrayResult = [];
                for (let i = 0; i < arrayLen; i++) {
                    const struct = structHelpers.NavContentItem.lift();
                    arrayResult.push(struct);
                }
                arrayResult.reverse();
            }
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const string = strStack.pop();
                optValue = string;
            }
            const string1 = strStack.pop();
            return { label: string1, directory: optValue, items: arrayResult };
        }
    });
    const __bjs_createNavViewerHelpers = () => ({
        lower: (value) => {
            i32Stack.push(value.isAuthenticated ? 1 : 0);
            const isSome = value.email != null ? 1 : 0;
            if (isSome) {
                const bytes = textEncoder.encode(value.email);
                const id = swift.memory.retain(bytes);
                i32Stack.push(bytes.length);
                i32Stack.push(id);
            }
            i32Stack.push(isSome);
        },
        lift: () => {
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const string = strStack.pop();
                optValue = string;
            }
            const bool = i32Stack.pop() !== 0;
            return { isAuthenticated: bool, email: optValue };
        }
    });
    const __bjs_createNavContentResponseHelpers = () => ({
        lower: (value) => {
            const bytes = textEncoder.encode(value.siteTitle);
            const id = swift.memory.retain(bytes);
            i32Stack.push(bytes.length);
            i32Stack.push(id);
            structHelpers.NavViewer.lower(value.viewer);
            structHelpers.NavContentItem.lower(value.home);
            for (const elem of value.groups) {
                structHelpers.NavContentGroup.lower(elem);
            }
            i32Stack.push(value.groups.length);
            const isSome = value.signIn != null ? 1 : 0;
            if (isSome) {
                structHelpers.NavSignInAction.lower(value.signIn);
            }
            i32Stack.push(isSome);
        },
        lift: () => {
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const struct = structHelpers.NavSignInAction.lift();
                optValue = struct;
            }
            const arrayLen = i32Stack.pop();
            let arrayResult;
            if (arrayLen === -1) {
                arrayResult = taStack.pop();
            } else {
                arrayResult = [];
                for (let i = 0; i < arrayLen; i++) {
                    const struct1 = structHelpers.NavContentGroup.lift();
                    arrayResult.push(struct1);
                }
                arrayResult.reverse();
            }
            const struct2 = structHelpers.NavContentItem.lift();
            const struct3 = structHelpers.NavViewer.lift();
            const string = strStack.pop();
            return { siteTitle: string, viewer: struct3, home: struct2, groups: arrayResult, signIn: optValue };
        }
    });
    const __bjs_createHistoryStateHelpers = () => ({
        lower: (value) => {
            const isSome = value.node != null ? 1 : 0;
            if (isSome) {
                i32Stack.push(value.node ? 1 : 0);
            }
            i32Stack.push(isSome);
            const isSome1 = value.contentPath != null ? 1 : 0;
            if (isSome1) {
                const bytes = textEncoder.encode(value.contentPath);
                const id = swift.memory.retain(bytes);
                i32Stack.push(bytes.length);
                i32Stack.push(id);
            }
            i32Stack.push(isSome1);
            const isSome2 = value.title != null ? 1 : 0;
            if (isSome2) {
                const bytes1 = textEncoder.encode(value.title);
                const id1 = swift.memory.retain(bytes1);
                i32Stack.push(bytes1.length);
                i32Stack.push(id1);
            }
            i32Stack.push(isSome2);
            const isSome3 = value.path != null ? 1 : 0;
            if (isSome3) {
                const bytes2 = textEncoder.encode(value.path);
                const id2 = swift.memory.retain(bytes2);
                i32Stack.push(bytes2.length);
                i32Stack.push(id2);
            }
            i32Stack.push(isSome3);
            const isSome4 = value.login != null ? 1 : 0;
            if (isSome4) {
                i32Stack.push(value.login ? 1 : 0);
            }
            i32Stack.push(isSome4);
            const isSome5 = value.verify != null ? 1 : 0;
            if (isSome5) {
                i32Stack.push(value.verify ? 1 : 0);
            }
            i32Stack.push(isSome5);
            const isSome6 = value.checkEmail != null ? 1 : 0;
            if (isSome6) {
                i32Stack.push(value.checkEmail ? 1 : 0);
            }
            i32Stack.push(isSome6);
            const isSome7 = value.notFound != null ? 1 : 0;
            if (isSome7) {
                i32Stack.push(value.notFound ? 1 : 0);
            }
            i32Stack.push(isSome7);
            const isSome8 = value.next != null ? 1 : 0;
            if (isSome8) {
                const bytes3 = textEncoder.encode(value.next);
                const id3 = swift.memory.retain(bytes3);
                i32Stack.push(bytes3.length);
                i32Stack.push(id3);
            }
            i32Stack.push(isSome8);
            const isSome9 = value.token != null ? 1 : 0;
            if (isSome9) {
                const bytes4 = textEncoder.encode(value.token);
                const id4 = swift.memory.retain(bytes4);
                i32Stack.push(bytes4.length);
                i32Stack.push(id4);
            }
            i32Stack.push(isSome9);
        },
        lift: () => {
            const isSome = i32Stack.pop();
            let optValue;
            if (isSome === 0) {
                optValue = null;
            } else {
                const string = strStack.pop();
                optValue = string;
            }
            const isSome1 = i32Stack.pop();
            let optValue1;
            if (isSome1 === 0) {
                optValue1 = null;
            } else {
                const string1 = strStack.pop();
                optValue1 = string1;
            }
            const isSome2 = i32Stack.pop();
            let optValue2;
            if (isSome2 === 0) {
                optValue2 = null;
            } else {
                const bool = i32Stack.pop() !== 0;
                optValue2 = bool;
            }
            const isSome3 = i32Stack.pop();
            let optValue3;
            if (isSome3 === 0) {
                optValue3 = null;
            } else {
                const bool1 = i32Stack.pop() !== 0;
                optValue3 = bool1;
            }
            const isSome4 = i32Stack.pop();
            let optValue4;
            if (isSome4 === 0) {
                optValue4 = null;
            } else {
                const bool2 = i32Stack.pop() !== 0;
                optValue4 = bool2;
            }
            const isSome5 = i32Stack.pop();
            let optValue5;
            if (isSome5 === 0) {
                optValue5 = null;
            } else {
                const bool3 = i32Stack.pop() !== 0;
                optValue5 = bool3;
            }
            const isSome6 = i32Stack.pop();
            let optValue6;
            if (isSome6 === 0) {
                optValue6 = null;
            } else {
                const string2 = strStack.pop();
                optValue6 = string2;
            }
            const isSome7 = i32Stack.pop();
            let optValue7;
            if (isSome7 === 0) {
                optValue7 = null;
            } else {
                const string3 = strStack.pop();
                optValue7 = string3;
            }
            const isSome8 = i32Stack.pop();
            let optValue8;
            if (isSome8 === 0) {
                optValue8 = null;
            } else {
                const string4 = strStack.pop();
                optValue8 = string4;
            }
            const isSome9 = i32Stack.pop();
            let optValue9;
            if (isSome9 === 0) {
                optValue9 = null;
            } else {
                const bool4 = i32Stack.pop() !== 0;
                optValue9 = bool4;
            }
            return { node: optValue9, contentPath: optValue8, title: optValue7, path: optValue6, login: optValue5, verify: optValue4, checkEmail: optValue3, notFound: optValue2, next: optValue1, token: optValue };
        }
    });

    return {
        /**
         * @param {WebAssembly.Imports} importObject
         */
        addImports: (importObject, importsContext) => {
            bjs = {};
            importObject["bjs"] = bjs;
            const imports = options.getImports(importsContext);
            bjs["swift_js_return_string"] = function(ptr, len) {
                tmpRetString = decodeString(ptr, len);
            }
            bjs["swift_js_init_memory"] = function(sourceId, bytesPtr) {
                const source = swift.memory.getObject(sourceId);
                swift.memory.release(sourceId);
                const bytes = new Uint8Array(memory.buffer, bytesPtr >>> 0);
                bytes.set(source);
            }
            bjs["swift_js_make_js_string"] = function(ptr, len) {
                return swift.memory.retain(decodeString(ptr, len));
            }
            bjs["swift_js_init_memory_with_result"] = function(ptr, len) {
                const target = new Uint8Array(memory.buffer, ptr >>> 0, len >>> 0);
                target.set(tmpRetBytes);
                tmpRetBytes = undefined;
            }
            bjs["swift_js_throw"] = function(id) {
                tmpRetException = swift.memory.retainByRef(id);
            }
            bjs["swift_js_retain"] = function(id) {
                return swift.memory.retainByRef(id);
            }
            bjs["swift_js_release"] = function(id) {
                swift.memory.release(id);
            }
            bjs["swift_js_push_i32"] = function(v) {
                i32Stack.push(v | 0);
            }
            bjs["swift_js_push_f32"] = function(v) {
                f32Stack.push(Math.fround(v));
            }
            bjs["swift_js_push_f64"] = function(v) {
                f64Stack.push(v);
            }
            bjs["swift_js_push_string"] = function(ptr, len) {
                const value = decodeString(ptr, len);
                strStack.push(value);
            }
            bjs["swift_js_pop_i32"] = function() {
                return i32Stack.pop();
            }
            bjs["swift_js_pop_f32"] = function() {
                return f32Stack.pop();
            }
            bjs["swift_js_pop_f64"] = function() {
                return f64Stack.pop();
            }
            bjs["swift_js_push_pointer"] = function(pointer) {
                ptrStack.push(pointer);
            }
            bjs["swift_js_pop_pointer"] = function() {
                return ptrStack.pop();
            }
            bjs["swift_js_push_i64"] = function(v) {
                i64Stack.push(v);
            }
            bjs["swift_js_pop_i64"] = function() {
                return i64Stack.pop();
            }
            const taCtors = [Int8Array, Uint8Array, Int16Array, Uint16Array, Int32Array, Uint32Array, Float32Array, Float64Array];
            bjs["swift_js_push_typed_array"] = function(kind, ptr, count) {
                const Ctor = taCtors[kind];
                const byteLen = count * Ctor.BYTES_PER_ELEMENT;
                const copy = memory.buffer.slice(ptr, ptr + byteLen);
                taStack.push(Array.from(new Ctor(copy)));
            }
            bjs["swift_js_struct_lower_PageMessage"] = function(objectId) {
                structHelpers.PageMessage.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_PageMessage"] = function() {
                const value = structHelpers.PageMessage.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_ShellMessage"] = function(objectId) {
                structHelpers.ShellMessage.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_ShellMessage"] = function() {
                const value = structHelpers.ShellMessage.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_NavContentItem"] = function(objectId) {
                structHelpers.NavContentItem.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_NavContentItem"] = function() {
                const value = structHelpers.NavContentItem.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_NavSignInAction"] = function(objectId) {
                structHelpers.NavSignInAction.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_NavSignInAction"] = function() {
                const value = structHelpers.NavSignInAction.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_NavContentGroup"] = function(objectId) {
                structHelpers.NavContentGroup.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_NavContentGroup"] = function() {
                const value = structHelpers.NavContentGroup.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_NavViewer"] = function(objectId) {
                structHelpers.NavViewer.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_NavViewer"] = function() {
                const value = structHelpers.NavViewer.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_NavContentResponse"] = function(objectId) {
                structHelpers.NavContentResponse.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_NavContentResponse"] = function() {
                const value = structHelpers.NavContentResponse.lift();
                return swift.memory.retain(value);
            }
            bjs["swift_js_struct_lower_HistoryState"] = function(objectId) {
                structHelpers.HistoryState.lower(swift.memory.getObject(objectId));
            }
            bjs["swift_js_struct_lift_HistoryState"] = function() {
                const value = structHelpers.HistoryState.lift();
                return swift.memory.retain(value);
            }
            const __bjs_promiseSettlers = Symbol("JavaScriptKit.promiseSettlers");
            bjs["swift_js_make_promise"] = function() {
                let resolve, reject;
                const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
                promise[__bjs_promiseSettlers] = { resolve, reject };
                return swift.memory.retain(promise);
            }
            bjs["swift_js_return_optional_bool"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalBool = null;
                } else {
                    tmpRetOptionalBool = value !== 0;
                }
            }
            bjs["swift_js_return_optional_int"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalInt = null;
                } else {
                    tmpRetOptionalInt = value | 0;
                }
            }
            bjs["swift_js_return_optional_float"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalFloat = null;
                } else {
                    tmpRetOptionalFloat = Math.fround(value);
                }
            }
            bjs["swift_js_return_optional_double"] = function(isSome, value) {
                if (isSome === 0) {
                    tmpRetOptionalDouble = null;
                } else {
                    tmpRetOptionalDouble = value;
                }
            }
            bjs["swift_js_return_optional_string"] = function(isSome, ptr, len) {
                if (isSome === 0) {
                    tmpRetString = null;
                } else {
                    tmpRetString = decodeString(ptr, len);
                }
            }
            bjs["swift_js_return_optional_object"] = function(isSome, objectId) {
                if (isSome === 0) {
                    tmpRetString = null;
                } else {
                    tmpRetString = swift.memory.getObject(objectId);
                }
            }
            bjs["swift_js_return_optional_heap_object"] = function(isSome, pointer) {
                if (isSome === 0) {
                    tmpRetOptionalHeapObject = null;
                } else {
                    tmpRetOptionalHeapObject = pointer;
                }
            }
            bjs["swift_js_get_optional_int_presence"] = function() {
                return tmpRetOptionalInt != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_int_value"] = function() {
                const value = tmpRetOptionalInt;
                tmpRetOptionalInt = undefined;
                return value;
            }
            bjs["swift_js_get_optional_string"] = function() {
                const str = tmpRetString;
                tmpRetString = undefined;
                if (str == null) {
                    return -1;
                } else {
                    const bytes = textEncoder.encode(str);
                    tmpRetBytes = bytes;
                    return bytes.length;
                }
            }
            bjs["swift_js_get_optional_float_presence"] = function() {
                return tmpRetOptionalFloat != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_float_value"] = function() {
                const value = tmpRetOptionalFloat;
                tmpRetOptionalFloat = undefined;
                return value;
            }
            bjs["swift_js_get_optional_double_presence"] = function() {
                return tmpRetOptionalDouble != null ? 1 : 0;
            }
            bjs["swift_js_get_optional_double_value"] = function() {
                const value = tmpRetOptionalDouble;
                tmpRetOptionalDouble = undefined;
                return value;
            }
            bjs["swift_js_get_optional_heap_object_pointer"] = function() {
                const pointer = tmpRetOptionalHeapObject;
                tmpRetOptionalHeapObject = undefined;
                return pointer || 0;
            }
            bjs["swift_js_closure_unregister"] = function(funcRef) {}
            bjs["swift_js_closure_unregister"] = function(funcRef) {
                const func = swift.memory.getObject(funcRef);
                func.__unregister();
            }
            bjs["invoke_js_callback_ShapeTreeCore_13ShapeTreeCore5EventC_y"] = function(callbackId, param0) {
                try {
                    const callback = swift.memory.getObject(callbackId);
                    callback(swift.memory.getObject(param0));
                } catch (error) {
                    setException(error);
                }
            }
            bjs["make_swift_closure_ShapeTreeCore_13ShapeTreeCore5EventC_y"] = function(boxPtr, file, line) {
                const lower_closure_ShapeTreeCore_13ShapeTreeCore5EventC_y = function(param0) {
                    instance.exports.invoke_swift_closure_ShapeTreeCore_13ShapeTreeCore5EventC_y(boxPtr, swift.memory.retain(param0));
                    if (tmpRetException) {
                        const error = swift.memory.getObject(tmpRetException);
                        swift.memory.release(tmpRetException);
                        tmpRetException = undefined;
                        throw error;
                    }
                };
                return makeClosure(boxPtr, file, line, lower_closure_ShapeTreeCore_13ShapeTreeCore5EventC_y);
            }
            bjs["invoke_js_callback_ShapeTreeCore_13ShapeTreeCoreSbSi_y"] = function(callbackId, param0, param1) {
                try {
                    const callback = swift.memory.getObject(callbackId);
                    callback(param0 !== 0, param1);
                } catch (error) {
                    setException(error);
                }
            }
            bjs["make_swift_closure_ShapeTreeCore_13ShapeTreeCoreSbSi_y"] = function(boxPtr, file, line) {
                const lower_closure_ShapeTreeCore_13ShapeTreeCoreSbSi_y = function(param0, param1) {
                    instance.exports.invoke_swift_closure_ShapeTreeCore_13ShapeTreeCoreSbSi_y(boxPtr, param0, param1);
                    if (tmpRetException) {
                        const error = swift.memory.getObject(tmpRetException);
                        swift.memory.release(tmpRetException);
                        tmpRetException = undefined;
                        throw error;
                    }
                };
                return makeClosure(boxPtr, file, line, lower_closure_ShapeTreeCore_13ShapeTreeCoreSbSi_y);
            }
            bjs["invoke_js_callback_ShapeTreeCore_13ShapeTreeCoreSq8JSObjectC_y"] = function(callbackId, param0IsSome, param0ObjectId) {
                try {
                    const callback = swift.memory.getObject(callbackId);
                    callback(param0IsSome ? swift.memory.getObject(param0ObjectId) : null);
                } catch (error) {
                    setException(error);
                }
            }
            bjs["make_swift_closure_ShapeTreeCore_13ShapeTreeCoreSq8JSObjectC_y"] = function(boxPtr, file, line) {
                const lower_closure_ShapeTreeCore_13ShapeTreeCoreSq8JSObjectC_y = function(param0) {
                    const isSome = param0 != null;
                    let result;
                    if (isSome) {
                        result = swift.memory.retain(param0);
                    } else {
                        result = 0;
                    }
                    instance.exports.invoke_swift_closure_ShapeTreeCore_13ShapeTreeCoreSq8JSObjectC_y(boxPtr, +isSome, result);
                    if (tmpRetException) {
                        const error = swift.memory.getObject(tmpRetException);
                        swift.memory.release(tmpRetException);
                        tmpRetException = undefined;
                        throw error;
                    }
                };
                return makeClosure(boxPtr, file, line, lower_closure_ShapeTreeCore_13ShapeTreeCoreSq8JSObjectC_y);
            }
            const ShapeTreeCore = importObject["ShapeTreeCore"] = importObject["ShapeTreeCore"] || {};
            ShapeTreeCore["bjs_webDocument_get"] = function bjs_webDocument_get() {
                try {
                    let ret = globalThis.document;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_webLocation_get"] = function bjs_webLocation_get() {
                try {
                    let ret = globalThis.location;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_webHistory_get"] = function bjs_webHistory_get() {
                try {
                    let ret = globalThis.history;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_webWindow_get"] = function bjs_webWindow_get() {
                try {
                    let ret = globalThis.window;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_webConsole_get"] = function bjs_webConsole_get() {
                try {
                    let ret = globalThis.console;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_hostFetchJSON"] = function bjs_hostFetchJSON(urlBytes, urlCount, completion) {
                try {
                    const string = decodeString(urlBytes, urlCount);
                    imports.hostFetchJSON(string, swift.memory.getObject(completion));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_hostMountModule"] = function bjs_hostMountModule(urlBytes, urlCount, completion) {
                try {
                    const string = decodeString(urlBytes, urlCount);
                    imports.hostMountModule(string, swift.memory.getObject(completion));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_hostSendToPage"] = function bjs_hostSendToPage(message) {
                try {
                    imports.hostSendToPage(swift.memory.getObject(message));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_encodeURIComponent"] = function bjs_encodeURIComponent(valueBytes, valueCount) {
                try {
                    const string = decodeString(valueBytes, valueCount);
                    let ret = imports.encodeURIComponent(string);
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_decodeURIComponent"] = function bjs_decodeURIComponent(valueBytes, valueCount) {
                try {
                    const string = decodeString(valueBytes, valueCount);
                    let ret = imports.decodeURIComponent(string);
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_createURLSearchParams"] = function bjs_createURLSearchParams(searchBytes, searchCount) {
                try {
                    const string = decodeString(searchBytes, searchCount);
                    let ret = imports.createURLSearchParams(string);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_Document_body_get"] = function bjs_Document_body_get(self) {
                try {
                    let ret = swift.memory.getObject(self).body;
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Document_title_get"] = function bjs_Document_title_get(self) {
                try {
                    let ret = swift.memory.getObject(self).title;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Document_title_set"] = function bjs_Document_title_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).title = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Document_getElementById"] = function bjs_Document_getElementById(self, idBytes, idCount) {
                try {
                    const string = decodeString(idBytes, idCount);
                    let ret = swift.memory.getObject(self).getElementById(string);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Document_createElement"] = function bjs_Document_createElement(self, tagBytes, tagCount) {
                try {
                    const string = decodeString(tagBytes, tagCount);
                    let ret = swift.memory.getObject(self).createElement(string);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_Document_querySelector"] = function bjs_Document_querySelector(self, selectorBytes, selectorCount) {
                try {
                    const string = decodeString(selectorBytes, selectorCount);
                    let ret = swift.memory.getObject(self).querySelector(string);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Document_addEventListener"] = function bjs_Document_addEventListener(self, typeBytes, typeCount, listener) {
                try {
                    const string = decodeString(typeBytes, typeCount);
                    swift.memory.getObject(self).addEventListener(string, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Window_addEventListener"] = function bjs_Window_addEventListener(self, typeBytes, typeCount, listener) {
                try {
                    const string = decodeString(typeBytes, typeCount);
                    swift.memory.getObject(self).addEventListener(string, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_id_get"] = function bjs_HTMLElement_id_get(self) {
                try {
                    let ret = swift.memory.getObject(self).id;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_className_get"] = function bjs_HTMLElement_className_get(self) {
                try {
                    let ret = swift.memory.getObject(self).className;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_innerHTML_get"] = function bjs_HTMLElement_innerHTML_get(self) {
                try {
                    let ret = swift.memory.getObject(self).innerHTML;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_textContent_get"] = function bjs_HTMLElement_textContent_get(self) {
                try {
                    let ret = swift.memory.getObject(self).textContent;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_tagName_get"] = function bjs_HTMLElement_tagName_get(self) {
                try {
                    let ret = swift.memory.getObject(self).tagName;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_href_get"] = function bjs_HTMLElement_href_get(self) {
                try {
                    let ret = swift.memory.getObject(self).href;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_htmlFor_get"] = function bjs_HTMLElement_htmlFor_get(self) {
                try {
                    let ret = swift.memory.getObject(self).htmlFor;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_hidden_get"] = function bjs_HTMLElement_hidden_get(self) {
                try {
                    let ret = swift.memory.getObject(self).hidden;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_checked_get"] = function bjs_HTMLElement_checked_get(self) {
                try {
                    let ret = swift.memory.getObject(self).checked;
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_classList_get"] = function bjs_HTMLElement_classList_get(self) {
                try {
                    let ret = swift.memory.getObject(self).classList;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_dataset_get"] = function bjs_HTMLElement_dataset_get(self) {
                try {
                    let ret = swift.memory.getObject(self).dataset;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_parentElement_get"] = function bjs_HTMLElement_parentElement_get(self) {
                try {
                    let ret = swift.memory.getObject(self).parentElement;
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_children_get"] = function bjs_HTMLElement_children_get(self) {
                try {
                    let ret = swift.memory.getObject(self).children;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_id_set"] = function bjs_HTMLElement_id_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).id = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_className_set"] = function bjs_HTMLElement_className_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).className = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_innerHTML_set"] = function bjs_HTMLElement_innerHTML_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).innerHTML = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_textContent_set"] = function bjs_HTMLElement_textContent_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).textContent = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_href_set"] = function bjs_HTMLElement_href_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).href = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_htmlFor_set"] = function bjs_HTMLElement_htmlFor_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).htmlFor = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_hidden_set"] = function bjs_HTMLElement_hidden_set(self, newValue) {
                try {
                    swift.memory.getObject(self).hidden = newValue !== 0;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_checked_set"] = function bjs_HTMLElement_checked_set(self, newValue) {
                try {
                    swift.memory.getObject(self).checked = newValue !== 0;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_appendChild"] = function bjs_HTMLElement_appendChild(self, child) {
                try {
                    let ret = swift.memory.getObject(self).appendChild(swift.memory.getObject(child));
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_replaceChildren"] = function bjs_HTMLElement_replaceChildren(self) {
                try {
                    swift.memory.getObject(self).replaceChildren();
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_setAttribute"] = function bjs_HTMLElement_setAttribute(self, nameBytes, nameCount, valueBytes, valueCount) {
                try {
                    const string = decodeString(nameBytes, nameCount);
                    const string1 = decodeString(valueBytes, valueCount);
                    swift.memory.getObject(self).setAttribute(string, string1);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_addEventListener"] = function bjs_HTMLElement_addEventListener(self, typeBytes, typeCount, listener) {
                try {
                    const string = decodeString(typeBytes, typeCount);
                    swift.memory.getObject(self).addEventListener(string, swift.memory.getObject(listener));
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_closest"] = function bjs_HTMLElement_closest(self, selectorBytes, selectorCount) {
                try {
                    const string = decodeString(selectorBytes, selectorCount);
                    let ret = swift.memory.getObject(self).closest(string);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_querySelector"] = function bjs_HTMLElement_querySelector(self, selectorBytes, selectorCount) {
                try {
                    const string = decodeString(selectorBytes, selectorCount);
                    let ret = swift.memory.getObject(self).querySelector(string);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_HTMLElement_querySelectorAll"] = function bjs_HTMLElement_querySelectorAll(self, selectorBytes, selectorCount) {
                try {
                    const string = decodeString(selectorBytes, selectorCount);
                    let ret = swift.memory.getObject(self).querySelectorAll(string);
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLElement_contains"] = function bjs_HTMLElement_contains(self, child) {
                try {
                    let ret = swift.memory.getObject(self).contains(swift.memory.getObject(child));
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_DOMTokenList_toggle"] = function bjs_DOMTokenList_toggle(self, tokenBytes, tokenCount, force) {
                try {
                    const string = decodeString(tokenBytes, tokenCount);
                    let ret = swift.memory.getObject(self).toggle(string, force !== 0);
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_DOMTokenList_contains"] = function bjs_DOMTokenList_contains(self, tokenBytes, tokenCount) {
                try {
                    const string = decodeString(tokenBytes, tokenCount);
                    let ret = swift.memory.getObject(self).contains(string);
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLCollection_length_get"] = function bjs_HTMLCollection_length_get(self) {
                try {
                    let ret = swift.memory.getObject(self).length;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_HTMLCollection_item"] = function bjs_HTMLCollection_item(self, index) {
                try {
                    let ret = swift.memory.getObject(self).item(index);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_NodeList_length_get"] = function bjs_NodeList_length_get(self) {
                try {
                    let ret = swift.memory.getObject(self).length;
                    return ret;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_NodeList_item"] = function bjs_NodeList_item(self, index) {
                try {
                    let ret = swift.memory.getObject(self).item(index);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Event_target_get"] = function bjs_Event_target_get(self) {
                try {
                    let ret = swift.memory.getObject(self).target;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_Event_key_get"] = function bjs_Event_key_get(self) {
                try {
                    let ret = swift.memory.getObject(self).key;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Event_state_get"] = function bjs_Event_state_get(self) {
                try {
                    let ret = swift.memory.getObject(self).state;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_Event_preventDefault"] = function bjs_Event_preventDefault(self) {
                try {
                    swift.memory.getObject(self).preventDefault();
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Location_pathname_get"] = function bjs_Location_pathname_get(self) {
                try {
                    let ret = swift.memory.getObject(self).pathname;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Location_search_get"] = function bjs_Location_search_get(self) {
                try {
                    let ret = swift.memory.getObject(self).search;
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_History_state_get"] = function bjs_History_state_get(self) {
                try {
                    let ret = swift.memory.getObject(self).state;
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_History_pushState"] = function bjs_History_pushState(self, state, unusedBytes, unusedCount, urlBytes, urlCount) {
                try {
                    const string = decodeString(unusedBytes, unusedCount);
                    const string1 = decodeString(urlBytes, urlCount);
                    swift.memory.getObject(self).pushState(swift.memory.getObject(state), string, string1);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_History_replaceState"] = function bjs_History_replaceState(self, state, unusedBytes, unusedCount, urlBytes, urlCount) {
                try {
                    const string = decodeString(unusedBytes, unusedCount);
                    const string1 = decodeString(urlBytes, urlCount);
                    swift.memory.getObject(self).replaceState(swift.memory.getObject(state), string, string1);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_URLSearchParams_has"] = function bjs_URLSearchParams_has(self, nameBytes, nameCount) {
                try {
                    const string = decodeString(nameBytes, nameCount);
                    let ret = swift.memory.getObject(self).has(string);
                    return ret ? 1 : 0;
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeCore["bjs_URLSearchParams_delete"] = function bjs_URLSearchParams_delete(self, nameBytes, nameCount) {
                try {
                    const string = decodeString(nameBytes, nameCount);
                    swift.memory.getObject(self).delete(string);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_URLSearchParams_get"] = function bjs_URLSearchParams_get(self, nameBytes, nameCount) {
                try {
                    const string = decodeString(nameBytes, nameCount);
                    let ret = swift.memory.getObject(self).get(string);
                    const isSome = ret != null;
                    tmpRetString = isSome ? ret : null;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_URLSearchParams_toString"] = function bjs_URLSearchParams_toString(self) {
                try {
                    let ret = swift.memory.getObject(self).toString();
                    tmpRetBytes = textEncoder.encode(ret);
                    return tmpRetBytes.length;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeCore["bjs_Console_log"] = function bjs_Console_log(self, messageBytes, messageCount) {
                try {
                    const string = decodeString(messageBytes, messageCount);
                    swift.memory.getObject(self).log(string);
                } catch (error) {
                    setException(error);
                }
            }
            const ShapeTreeKit = importObject["ShapeTreeKit"] = importObject["ShapeTreeKit"] || {};
            ShapeTreeKit["bjs_pageDocument_get"] = function bjs_pageDocument_get() {
                try {
                    let ret = globalThis.document;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeKit["bjs_pageConsole_get"] = function bjs_pageConsole_get() {
                try {
                    let ret = globalThis.console;
                    return swift.memory.retain(ret);
                } catch (error) {
                    setException(error);
                    return 0
                }
            }
            ShapeTreeKit["bjs_hostPostToShell"] = function bjs_hostPostToShell(message) {
                try {
                    const value = swift.memory.getObject(message);
                    swift.memory.release(message);
                    imports.hostPostToShell(value);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeKit["bjs_PageDocument_getElementById"] = function bjs_PageDocument_getElementById(self, idBytes, idCount) {
                try {
                    const string = decodeString(idBytes, idCount);
                    let ret = swift.memory.getObject(self).getElementById(string);
                    const isSome = ret != null;
                    if (isSome) {
                        const objId = swift.memory.retain(ret);
                        i32Stack.push(objId);
                    }
                    i32Stack.push(isSome ? 1 : 0);
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeKit["bjs_PageHTMLElement_innerHTML_set"] = function bjs_PageHTMLElement_innerHTML_set(self, newValueBytes, newValueCount) {
                try {
                    const string = decodeString(newValueBytes, newValueCount);
                    swift.memory.getObject(self).innerHTML = string;
                } catch (error) {
                    setException(error);
                }
            }
            ShapeTreeKit["bjs_PageConsole_log"] = function bjs_PageConsole_log(self, messageBytes, messageCount) {
                try {
                    const string = decodeString(messageBytes, messageCount);
                    swift.memory.getObject(self).log(string);
                } catch (error) {
                    setException(error);
                }
            }
        },
        setInstance: (i) => {
            instance = i;
            memory = instance.exports.memory;

            decodeString = (ptr, len) => { const bytes = new Uint8Array(memory.buffer, ptr >>> 0, len >>> 0); return textDecoder.decode(bytes); }

            setException = (error) => {
                instance.exports._swift_js_exception.value = swift.memory.retain(error)
            }
        },
        /** @param {WebAssembly.Instance} instance */
        createExports: (instance) => {
            const js = swift.memory.heap;
            const PageMessageHelpers = __bjs_createPageMessageHelpers();
            structHelpers.PageMessage = PageMessageHelpers;

            const ShellMessageHelpers = __bjs_createShellMessageHelpers();
            structHelpers.ShellMessage = ShellMessageHelpers;

            const NavContentItemHelpers = __bjs_createNavContentItemHelpers();
            structHelpers.NavContentItem = NavContentItemHelpers;

            const NavSignInActionHelpers = __bjs_createNavSignInActionHelpers();
            structHelpers.NavSignInAction = NavSignInActionHelpers;

            const NavContentGroupHelpers = __bjs_createNavContentGroupHelpers();
            structHelpers.NavContentGroup = NavContentGroupHelpers;

            const NavViewerHelpers = __bjs_createNavViewerHelpers();
            structHelpers.NavViewer = NavViewerHelpers;

            const NavContentResponseHelpers = __bjs_createNavContentResponseHelpers();
            structHelpers.NavContentResponse = NavContentResponseHelpers;

            const HistoryStateHelpers = __bjs_createHistoryStateHelpers();
            structHelpers.HistoryState = HistoryStateHelpers;

            const exports = {
                handlePageMessage: function bjs_handlePageMessage(message) {
                    instance.exports.bjs_handlePageMessage(swift.memory.retain(message));
                },
                PageMessage: {
                    init: function(kind, path, payload) {
                        const kindBytes = textEncoder.encode(kind);
                        const kindId = swift.memory.retain(kindBytes);
                        const isSome = path != null;
                        let result, result1;
                        if (isSome) {
                            const pathBytes = textEncoder.encode(path);
                            const pathId = swift.memory.retain(pathBytes);
                            result = pathId;
                            result1 = pathBytes.length;
                        } else {
                            result = 0;
                            result1 = 0;
                        }
                        const isSome1 = payload != null;
                        let result2, result3;
                        if (isSome1) {
                            const payloadBytes = textEncoder.encode(payload);
                            const payloadId = swift.memory.retain(payloadBytes);
                            result2 = payloadId;
                            result3 = payloadBytes.length;
                        } else {
                            result2 = 0;
                            result3 = 0;
                        }
                        instance.exports.bjs_PageMessage_init(kindId, kindBytes.length, +isSome, result, result1, +isSome1, result2, result3);
                        const structValue = structHelpers.PageMessage.lift();
                        return structValue;
                    },
                },
                ShellMessage: {
                    init: function(kind, payload) {
                        const kindBytes = textEncoder.encode(kind);
                        const kindId = swift.memory.retain(kindBytes);
                        const isSome = payload != null;
                        let result, result1;
                        if (isSome) {
                            const payloadBytes = textEncoder.encode(payload);
                            const payloadId = swift.memory.retain(payloadBytes);
                            result = payloadId;
                            result1 = payloadBytes.length;
                        } else {
                            result = 0;
                            result1 = 0;
                        }
                        instance.exports.bjs_ShellMessage_init(kindId, kindBytes.length, +isSome, result, result1);
                        const structValue = structHelpers.ShellMessage.lift();
                        return structValue;
                    },
                },
                NavContentItem: {
                    init: function(path, slug, title, href, hasWasm) {
                        const pathBytes = textEncoder.encode(path);
                        const pathId = swift.memory.retain(pathBytes);
                        const slugBytes = textEncoder.encode(slug);
                        const slugId = swift.memory.retain(slugBytes);
                        const titleBytes = textEncoder.encode(title);
                        const titleId = swift.memory.retain(titleBytes);
                        const hrefBytes = textEncoder.encode(href);
                        const hrefId = swift.memory.retain(hrefBytes);
                        instance.exports.bjs_NavContentItem_init(pathId, pathBytes.length, slugId, slugBytes.length, titleId, titleBytes.length, hrefId, hrefBytes.length, hasWasm);
                        const structValue = structHelpers.NavContentItem.lift();
                        return structValue;
                    },
                },
                NavSignInAction: {
                    init: function(href, label, spa) {
                        const hrefBytes = textEncoder.encode(href);
                        const hrefId = swift.memory.retain(hrefBytes);
                        const labelBytes = textEncoder.encode(label);
                        const labelId = swift.memory.retain(labelBytes);
                        instance.exports.bjs_NavSignInAction_init(hrefId, hrefBytes.length, labelId, labelBytes.length, spa);
                        const structValue = structHelpers.NavSignInAction.lift();
                        return structValue;
                    },
                },
                NavContentGroup: {
                    init: function(label, directory, items) {
                        const labelBytes = textEncoder.encode(label);
                        const labelId = swift.memory.retain(labelBytes);
                        const isSome = directory != null;
                        let result, result1;
                        if (isSome) {
                            const directoryBytes = textEncoder.encode(directory);
                            const directoryId = swift.memory.retain(directoryBytes);
                            result = directoryId;
                            result1 = directoryBytes.length;
                        } else {
                            result = 0;
                            result1 = 0;
                        }
                        for (const elem of items) {
                            structHelpers.NavContentItem.lower(elem);
                        }
                        i32Stack.push(items.length);
                        instance.exports.bjs_NavContentGroup_init(labelId, labelBytes.length, +isSome, result, result1);
                        const structValue = structHelpers.NavContentGroup.lift();
                        return structValue;
                    },
                },
                NavViewer: {
                    init: function(isAuthenticated, email) {
                        const isSome = email != null;
                        let result, result1;
                        if (isSome) {
                            const emailBytes = textEncoder.encode(email);
                            const emailId = swift.memory.retain(emailBytes);
                            result = emailId;
                            result1 = emailBytes.length;
                        } else {
                            result = 0;
                            result1 = 0;
                        }
                        instance.exports.bjs_NavViewer_init(isAuthenticated, +isSome, result, result1);
                        const structValue = structHelpers.NavViewer.lift();
                        return structValue;
                    },
                },
                NavContentResponse: {
                    init: function(siteTitle, viewer, home, groups, signIn) {
                        const siteTitleBytes = textEncoder.encode(siteTitle);
                        const siteTitleId = swift.memory.retain(siteTitleBytes);
                        structHelpers.NavViewer.lower(viewer);
                        structHelpers.NavContentItem.lower(home);
                        for (const elem of groups) {
                            structHelpers.NavContentGroup.lower(elem);
                        }
                        i32Stack.push(groups.length);
                        const isSome = signIn != null;
                        if (isSome) {
                            structHelpers.NavSignInAction.lower(signIn);
                        }
                        i32Stack.push(+isSome);
                        instance.exports.bjs_NavContentResponse_init(siteTitleId, siteTitleBytes.length);
                        const structValue = structHelpers.NavContentResponse.lift();
                        return structValue;
                    },
                },
                HistoryState: {
                    init: function(node = null, contentPath = null, title = null, path = null, login = null, verify = null, checkEmail = null, notFound = null, next = null, token = null) {
                        const isSome = node != null;
                        const isSome1 = contentPath != null;
                        let result, result1;
                        if (isSome1) {
                            const contentPathBytes = textEncoder.encode(contentPath);
                            const contentPathId = swift.memory.retain(contentPathBytes);
                            result = contentPathId;
                            result1 = contentPathBytes.length;
                        } else {
                            result = 0;
                            result1 = 0;
                        }
                        const isSome2 = title != null;
                        let result2, result3;
                        if (isSome2) {
                            const titleBytes = textEncoder.encode(title);
                            const titleId = swift.memory.retain(titleBytes);
                            result2 = titleId;
                            result3 = titleBytes.length;
                        } else {
                            result2 = 0;
                            result3 = 0;
                        }
                        const isSome3 = path != null;
                        let result4, result5;
                        if (isSome3) {
                            const pathBytes = textEncoder.encode(path);
                            const pathId = swift.memory.retain(pathBytes);
                            result4 = pathId;
                            result5 = pathBytes.length;
                        } else {
                            result4 = 0;
                            result5 = 0;
                        }
                        const isSome4 = login != null;
                        const isSome5 = verify != null;
                        const isSome6 = checkEmail != null;
                        const isSome7 = notFound != null;
                        const isSome8 = next != null;
                        let result6, result7;
                        if (isSome8) {
                            const nextBytes = textEncoder.encode(next);
                            const nextId = swift.memory.retain(nextBytes);
                            result6 = nextId;
                            result7 = nextBytes.length;
                        } else {
                            result6 = 0;
                            result7 = 0;
                        }
                        const isSome9 = token != null;
                        let result8, result9;
                        if (isSome9) {
                            const tokenBytes = textEncoder.encode(token);
                            const tokenId = swift.memory.retain(tokenBytes);
                            result8 = tokenId;
                            result9 = tokenBytes.length;
                        } else {
                            result8 = 0;
                            result9 = 0;
                        }
                        instance.exports.bjs_HistoryState_init(+isSome, isSome ? node ? 1 : 0 : 0, +isSome1, result, result1, +isSome2, result2, result3, +isSome3, result4, result5, +isSome4, isSome4 ? login ? 1 : 0 : 0, +isSome5, isSome5 ? verify ? 1 : 0 : 0, +isSome6, isSome6 ? checkEmail ? 1 : 0 : 0, +isSome7, isSome7 ? notFound ? 1 : 0 : 0, +isSome8, result6, result7, +isSome9, result8, result9);
                        const structValue = structHelpers.HistoryState.lift();
                        return structValue;
                    },
                },
            };
            _exports = exports;
            return exports;
        },
    }
}