using VTKBase:
    VTKPolyhedron,
    faces

function process_faces!(data, cell::VTKPolyhedron, offset)
    fs = faces(cell)
    num_faces = length(fs)
    num_values = 1 + sum(x -> length(x) + 1, fs)
    resize!(data, length(data) + num_values)
    @inbounds data[offset += 1] = num_faces
    @inbounds for f in fs
        data[offset += 1] = length(f)
        for idx in f
            data[offset += 1] = idx - 1  # switch to zero-based indexing
        end
    end
    num_values
end
