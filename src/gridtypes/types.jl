"""
    AbstractVTKDataset

Abstract type representing any structured or unstructured VTK dataset.

The dataset classification is described in the
[VTK file format
specification](https://vtk.org/wp-content/uploads/2015/04/file-formats.pdf),
page 12.
"""
abstract type AbstractVTKDataset end

"""
    StructuredVTKDataset <: AbstractVTKDataset

Abstract type representing a structured VTK dataset.

Subtypes are `VTKImageData`, `VTKRectilinearGrid` and `VTKStructuredGrid`.
"""
abstract type StructuredVTKDataset <: AbstractVTKDataset end

struct VTKImageData <: StructuredVTKDataset end
struct VTKRectilinearGrid <: StructuredVTKDataset end
struct VTKStructuredGrid <: StructuredVTKDataset end

"""
    UnstructuredVTKDataset <: AbstractVTKDataset

Abstract type representing an unstructured VTK dataset.

Subtypes are `VTKPolyData` and `VTKUnstructuredGrid`.
"""
abstract type UnstructuredVTKDataset <: AbstractVTKDataset end

struct VTKPolyData <: UnstructuredVTKDataset end
struct VTKUnstructuredGrid <: UnstructuredVTKDataset end

"""
    ParaviewCollection <: AbstractVTKDataset

Represents a ParaView collection file (`*.pvd`).
"""
abstract type ParaviewCollection <: AbstractVTKDataset end

file_extension(::VTKImageData) = ".vti"
file_extension(::VTKRectilinearGrid) = ".vtr"
file_extension(::VTKStructuredGrid) = ".vts"
file_extension(::VTKPolyData) = ".vtp"
file_extension(::VTKUnstructuredGrid) = ".vtu"

xml_name(::VTKImageData) = "ImageData"
xml_name(::VTKRectilinearGrid) = "RectilinearGrid"
xml_name(::VTKStructuredGrid) = "StructuredGrid"
xml_name(::VTKPolyData) = "PolyData"
xml_name(::VTKUnstructuredGrid) = "UnstructuredGrid"
