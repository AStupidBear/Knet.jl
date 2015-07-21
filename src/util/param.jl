import Base: convert

type KUparam{A,T,N}; arr; diff; lr; l1reg; l2reg; adagrad; ada; momentum; mom; nesterov; nes; average; avg; KUparam()=new(); end

setparam!(p::KUparam; o...)=(for (n,v) in o; p.(n)=v; end; p)
KUparam(w; init=nothing, o...)=setparam!(KUparam{atype(w),eltype(w),ndims(w)}(); arr=(init==nothing?w:init(w)), o...)
KUparam{A,T}(::Type{A}, ::Type{T}, d::Dims; o...)=KUparam(A(T,d); o...)
KUparam{T}(::Type{T}, d::Dims; o...)=KUparam((gpu()?CudaArray:Array)(T,d); o...)
KUparam{T}(::Type{T}, d::Int...; o...)=KUparam(T,d; o...)
KUparam(d1::Int,d::Int...; o...)=KUparam(Float64,tuple(d1,d...); o...)

# We probably don't need this copy, just implement cpucopy and gpucopy.
# copy(p::KUparam; o...)=(q=KUparam(); for n in names(p); isdefined(p,n) && q.(n)=copy(p.(n)); end; q)

# BASIC ARRAY OPS:

for fname in (:eltype, :length, :ndims, :size, :strides, :pointer, :isempty)
    @eval (Base.$fname)(a::KUparam)=$fname(a.arr)
end

for fname in (:size, :stride)
    @eval (Base.$fname)(a::KUparam,n)=$fname(a.arr,n)
end

atype{A}(::KUparam{A})=A
diff(a::KUparam)=a.diff

update(::Nothing;o...)=nothing
setparam!(::Nothing;o...)=nothing
initdiff(w::KUparam;o...)=similar!(w, :diff, w.arr)

initzero(a)=(fill!(a,zero(eltype(a))); a)
initgaussian(a, std=0.01, mean=0.0)=(randn!(a,std,mean); a)
initxavier(a)=(fanin = length(a) / (size(a)[end]); scale = sqrt(3 / fanin); rand!(a, -scale, scale); a)

# We need to fix cpu/gpu copy so the type changes appropriately:
function cpucopy_internal{T,N}(x::KUparam{CudaArray,T,N},d::ObjectIdDict)
    haskey(d,x) && return d[x]
    y = KUparam{Array,T,N}()
    for n in names(x)
        isdefined(x,n) || continue
        y.(n) = cpucopy_internal(x.(n),d)
    end
    d[x] = y
end

function gpucopy_internal{T,N}(x::KUparam{Array,T,N},d::ObjectIdDict)
    haskey(d,x) && return d[x]
    y = KUparam{CudaArray,T,N}()
    for n in names(x)
        isdefined(x,n) || continue
        y.(n) = gpucopy_internal(x.(n),d)
    end
    d[x] = y
end

convert{A<:BaseArray}(::Type{A}, a::KUparam)=convert(A, a.arr)
convert{A<:BaseArray}(::Type{KUparam}, a::A)=KUparam(a)
