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

Subtypes are [`VTKImageData`](@ref), [`VTKRectilinearGrid`](@ref) and
[`VTKStructuredGrid`](@ref).
"""
abstract type StructuredVTKDataset <: AbstractVTKDataset end

"""
    VTKImageData <: StructuredVTKDataset

Represents the VTK image data format (`.vti` extension).

This corresponds to rectangular grids with uniform spacing in all directions.
"""
struct VTKImageData <: StructuredVTKDataset end

"""
    VTKRectilinearGrid <: StructuredVTKDataset

Represents the VTK rectilinear grid format (`.vtr` extension).

This corresponds to rectangular grids with non-uniform spacing.
"""
struct VTKRectilinearGrid <: StructuredVTKDataset end

"""
    VTKStructuredGrid <: StructuredVTKDataset

Represents the VTK structured grid format (`.vts` extension).

This corresponds to curvilinear grids, the most general kind of structured grid.
"""
struct VTKStructuredGrid <: StructuredVTKDataset end

"""
    UnstructuredVTKDataset <: AbstractVTKDataset

Abstract type representing an unstructured VTK dataset.

Subtypes are [`VTKPolyData`](@ref) and [`VTKUnstructuredGrid`](@ref).
"""
abstract type UnstructuredVTKDataset <: AbstractVTKDataset end

"""
    VTKPolyData <: UnstructuredVTKDataset

Represents the VTK polydata format (`.vtp` extension).

These are unstructured datasets that accept a limited set of cells types,
defined in the [`PolyData`](@ref) module.
"""
struct VTKPolyData <: UnstructuredVTKDataset end

"""
    VTKUnstructuredGrid <: UnstructuredVTKDataset

Represents the VTK unstructured format (`.vtu` extension).

This is the most general kind of unstructured grid, which accepts all cell types
defined in the [`VTKCellTypes`](@ref) module.
"""
struct VTKUnstructuredGrid <: UnstructuredVTKDataset end

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
