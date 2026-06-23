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
            const exports = {
            };
            _exports = exports;
            return exports;
        },
    }
}