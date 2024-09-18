function vtk_save(vtk::DatasetFile)
    if isopen(vtk)
        if vtk.appended
            save_with_appended_data(vtk)
        else
            save_file(vtk.xdoc, vtk.path)
        end
    end
    if isopen(vtk)  # just in case the XML handler was freed by calls to save_* above
        close_xml(vtk)
    end
    return [vtk.path] :: Vector{String}
end


"""
Write VTK XML file containing appended binary data to disk.

In this case, the XML file is written manually instead of using the `save_file`
function of `LightXML`, which doesn't allow to write raw binary data.
"""
function save_with_appended_data(vtk::DatasetFile)
    @assert vtk.appended
    @assert isopen(vtk.buf)

    # Convert XML document to a string, and split the last two lines.
    lines = rsplit(string(vtk.xdoc), '\n', limit=3, keepempty=true)

    # Verify that the last two lines are what they're supposed to be.
    @assert lines[2] == "</VTKFile>"
    @assert lines[3] == ""

    open(vtk.path, "w") do io
        # Write everything but the last two lines.
        write(io, lines[1])
        write(io, "\n")

        # Write raw data (contents of buffer vtk.buf).
        # An underscore "_" is needed before writing appended data.
        write(io, "  <AppendedData encoding=\"raw\">")
        write(io, "\n_")
        write(io, take!(vtk.buf))
        write(io, "\n  </AppendedData>")
        write(io, "\n</VTKFile>")

        close(vtk.buf)
    end

    nothing
end
