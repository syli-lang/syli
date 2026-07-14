# Syli Roadmap

## Language Level
These are objectifs to reach but they are not fixed and could change or being improved.


- [ ] Functional Core
    - immediates:
      - int32, int64, float, int8, unit, int16, bool, str, char
    - binary op
    - function/closure 
    - condition, let
    - simple ffi C
    - RC on objects/closure
    - stringLit -> str (static memory)
    - charLit -> char (interger)

- [ ] array and record
    - record with immutable fields
    - array with immediates and record
    - array type will be [ty:N] ex. [i64:N]
    - multi-dimension array will ex. [[i64:N]:N] (represented internally in one dimension)

- [ ] Mutable
    - introduce weak type or restrict polymorphic with memory.
    - Ref
      - type ref int -> {mutable value: int}
      - ops: "!", ":="
    - Record with mutable field
    - roots objects for tracing cylic objects

- [ ] Loops:
    - loop
    - forIn

- [ ] string & stringVec (for testing record & array & loops)
    - type string = [i32:N]
    - type stringVec = { mutable value: [i64:N] }
      - first element -> size
      - second -> capacity
      - rest the string

- [ ] Parametrics type
    - type definitiosn:
      - type m 'a = {value : 'a}

- [ ] Pattern Matching
    - support variant
    - support tuple
    - support pattern of immediate, variant, record, ident, tuple

- [ ] list (testing parametric type & pattern matching)
    - type list 'a = [] | (::) of ('a, list 'a)

- [ ] Pattern match collection
    - list:  []   [x]     [x;y]
    - array: [,]  [x,]    [x,y]
    - set:   {;}  {x}     {x;y}
    - map:   {}   {k->v}  {k1->v1;k2->v2}

- [ ] Exceptions
    - try catch
    - raise
    - invoke llvm kind is used

- [ ] FFI C
    - Custom object definition (in the language itself)
    - Finalizers with bindings

- [ ] Module system
    - signature
    - structure
    - a .sy file as a module
    - compilation unit
        - syi generate smi (compiled module interface)
        - sy generate symo (compile module object), symi, symg (generics), syml (inlinable)
    - Primitive types annotations like.
      - type char = int32 [@abstract, @primitive], primitive override type with "open" module. In signature you could do "type char [@primitive]"

- [ ] Start the Std library (module)

- [ ] Traits
    - support traits
    - add arithmetic ops traits: - * / +
    - add indexable traits ex. obj[index]
    - collections powered by traits:
        - list:  []   [x]       [x;y]
        - array: [,]  [x,]      [x,y]
        - set:   {;}  {x}       {x;y}
        - map:   {}   {k->v}    {k1->v1;k2->v2}

- [ ] Dyn Trait

- [ ] Algebraic Effect handlers

- [ ] Domains (Arc object vs Rc object local thread)
    - threads TLS domains
    - ownership(move) around thread boundaries
    - introduce arc and mutex annotations:
        - array variant, record : @arc array, @mutex array
        - custom obj (ffi)
    - the runtime will be improved to support more thread.
        
## Runtime level

- [X] Rc system single thread
- [X] single thread handle cyclic with tracing fallback
- [ ] Support variant tag
- [ ] Exception support
- [ ] Fibers for algebraic effect handlers
- [ ] Domains threads support

## Could be added in any version

- [ ] Rank-2 polymorphism
  
    Could be done by extending the closure_graph and supporting it in the type system.
    - [ ] function as an argument, first
    - [ ] partially applied function as an argument in second