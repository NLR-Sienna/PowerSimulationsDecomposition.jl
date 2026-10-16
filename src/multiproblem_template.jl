"""
    MultiProblemTemplate(base_template::PSI.ProblemTemplate, problem_keys::Vector{String})
    MultiProblemTemplate(network::PSI.NetworkModel, problem_keys::Vector{String})

Store a base template and an independent regional copy for each subsystem key.

Retain a supplied `base_template` by reference and deep-copy it for the regional
templates. For a supplied `network`, first construct the base
`PSI.ProblemTemplate`. Use PowerSimulations' model setters to configure the
templates.

Keys identify PowerSystems named subsystems when the template is used with a
System. Construction does not validate those memberships, assign components,
or infer a partition. DecisionModel construction copies and finalizes the
templates, removing empty regional device and branch models.
"""
struct MultiProblemTemplate <: PSI.AbstractProblemTemplate
    base_template::PSI.ProblemTemplate
    sub_templates::Dict{String, PSI.ProblemTemplate}
end

PSI.get_device_models(template::MultiProblemTemplate) = template.base_template.devices
PSI.get_branch_models(template::MultiProblemTemplate) = template.base_template.branches
PSI.get_service_models(template::MultiProblemTemplate) = template.base_template.services
PSI.get_network_model(template::MultiProblemTemplate) = template.base_template.network_model

"""
    MultiProblemTemplate(base_template::PSI.ProblemTemplate,
                         problem_keys::Vector{String})

Retain `base_template` and deep-copy it for each regional key in `problem_keys`.

Store the supplied base object without copying it. Each regional template is a
separate deep copy, so later regional edits do not modify the base template.
Do not assign System components or rewrite subsystem filters already present
in the supplied template.
"""
function MultiProblemTemplate(
    base_template::PSI.ProblemTemplate,
    problem_keys::Vector{String},
)
    sub_templates = Dict{String, PSI.ProblemTemplate}(
        k => deepcopy(base_template) for k in problem_keys
    )
    return MultiProblemTemplate(base_template, sub_templates)
end

"""
    MultiProblemTemplate(network::PSI.NetworkModel{T},
                         problem_keys::Vector{String}) where {T <: PM.AbstractPowerModel}

Construct a base problem template from `network` and deep-copy it for each key.

Pass `network` to the upstream `PSI.ProblemTemplate` constructor, then delegate
to the base-template constructor. The network formulation must subtype
`PM.AbstractPowerModel`. Do not assign components to the named subsystems.
"""
function MultiProblemTemplate(
    network::PSI.NetworkModel{T},
    problem_keys::Vector{String},
) where {T <: PM.AbstractPowerModel}
    return MultiProblemTemplate(PSI.ProblemTemplate(network), problem_keys)
end

function Base.isempty(template::MultiProblemTemplate)
    for template in values(template.sub_templates)
        if !isempty(template.sub_templates)
            return false
        end
    end
    return isempty(template.base_template)
end

"""
    PSI.get_network_formulation(template::MultiProblemTemplate)

Return the network formulation type configured in the base template.

Do not inspect or reconcile the formulations of the regional templates.
"""
function PSI.get_network_formulation(template::MultiProblemTemplate)
    bt = template.base_template
    return PSI.get_network_formulation(PSI.get_network_model(bt))
end

"""
    get_sub_templates(template::MultiProblemTemplate)

Return the dictionary mapping subsystem keys to regional problem templates.

Return the stored dictionary, not a copy. Mutating it or its template values
modifies `template`.
"""
function get_sub_templates(template::MultiProblemTemplate)
    return template.sub_templates
end

"""
    get_sub_problem_keys(template::MultiProblemTemplate)

Return a newly allocated, lexicographically sorted vector of regional keys.

Leave the stored dictionary and its iteration order unchanged.
"""
function get_sub_problem_keys(template::MultiProblemTemplate)
    return sort!(collect(keys(get_sub_templates(template))))
end

"""
    PSI.get_component_types(template::MultiProblemTemplate)

Collect device, branch, and service component types from the base template.

The intended result is a `Vector{DataType}` concatenated in that category order,
without sorting or deduplication. Do not inspect the regional templates.

## Notes

The current implementation raises `UndefVarError` because its upstream helper
calls are unqualified. See [issue #28](https://github.com/NLR-Sienna/PowerSimulationsDecomposition.jl/issues/28).
This limitation is documented here without changing the implementation.
"""
function PSI.get_component_types(template::MultiProblemTemplate)::Vector{DataType}
    base_template = template.base_template
    return vcat(
        get_component_type.(values(get_device_models(base_template))),
        get_component_type.(values(get_branch_models(base_template))),
        get_component_type.(values(get_service_models(base_template))),
    )
end

"""
    PSI.get_model(template::MultiProblemTemplate, ::Type{T}) where {T <: PSY.Device}

Return the base-template model for device or branch type `T`.

Delegate key handling to PowerSimulations and return the stored model by
reference, or `nothing` when no model of that type is configured.
"""
function PSI.get_model(template::MultiProblemTemplate, ::Type{T}) where {T <: PSY.Device}
    return PSI.get_model(template.base_template, T)
end

"""
    PSI.get_model(template::MultiProblemTemplate, ::Type{T},
                  subsystem::String) where {T <: PSY.Device}

Return the regional device or branch model for `T` and `subsystem`.

Delegate lookup to the selected upstream problem template. Return the stored
model by reference, or `nothing` when the region has no model of type `T`.
Throw `KeyError` when `subsystem` is not a regional template key.
"""
function PSI.get_model(
    template::MultiProblemTemplate,
    ::Type{T},
    subsystem::String,
) where {T <: PSY.Device}
    return PSI.get_model(template.sub_templates[subsystem], T)
end

"""
    PSI.set_network_model!(template::MultiProblemTemplate,
                           model::PSI.NetworkModel{<:PM.AbstractPowerModel})

Store `model` in the base and every regional template without copying it.

Set its subsystem field to each regional key before storing it there. All
templates share the same mutable model, and its final subsystem is the last
key visited in dictionary iteration. Return `nothing`.
"""
function PSI.set_network_model!(
    template::MultiProblemTemplate,
    model::PSI.NetworkModel{<:PM.AbstractPowerModel},
)
    PSI.set_network_model!(template.base_template, model)
    for (id, sub_template) in get_sub_templates(template)
        PSI.set_subsystem!(model, id)
        PSI.set_network_model!(sub_template, model)
    end
    return
end

"""
    PSI.set_device_model!(template::MultiProblemTemplate,
                          component_type::Type{<:PSY.Device},
                          formulation::Type{<:PSI.AbstractDeviceFormulation})

Create default device models for the base and every regional template.

Construct a separate `PSI.DeviceModel` for each template using
`component_type` and `formulation`. Set each regional model's subsystem to its
template key and use the upstream defaults for other settings. Return `nothing`.
"""
function PSI.set_device_model!(
    template::MultiProblemTemplate,
    component_type::Type{<:PSY.Device},
    formulation::Type{<:PSI.AbstractDeviceFormulation},
)
    PSI.set_device_model!(
        template.base_template,
        PSI.DeviceModel(component_type, formulation),
    )
    for (id, sub_template) in get_sub_templates(template)
        network_model = PSI.DeviceModel(component_type, formulation)
        PSI.set_subsystem!(network_model, id)
        PSI.set_device_model!(sub_template, network_model)
    end
    return
end

"""
    PSI.set_device_model!(template::MultiProblemTemplate,
                          model::PSI.DeviceModel{<:PSY.Device, <:PSI.AbstractDeviceFormulation})

Store `model` in the base and a deep copy in every regional template.

Set each copy's subsystem to its regional key without changing the supplied
model's subsystem. Retain the original model by reference in the base template
and return `nothing`.
"""
function PSI.set_device_model!(
    template::MultiProblemTemplate,
    model::PSI.DeviceModel{<:PSY.Device, <:PSI.AbstractDeviceFormulation},
)
    PSI.set_device_model!(template.base_template, model)
    for (id, sub_template) in get_sub_templates(template)
        new_model = deepcopy(model)
        PSI.set_subsystem!(new_model, id)
        PSI.set_device_model!(sub_template, new_model)
    end
    return
end

"""
    PSI.set_device_model!(template::MultiProblemTemplate,
                          model::PSI.DeviceModel{<:PSY.Branch, <:PSI.AbstractDeviceFormulation})

Store the branch `model` in the base and a deep copy in every regional template.

Set each regional copy's subsystem to its key. Do not mutate the supplied
model's subsystem; retain it by reference in the base and return `nothing`.
"""
function PSI.set_device_model!(
    template::MultiProblemTemplate,
    model::PSI.DeviceModel{<:PSY.Branch, <:PSI.AbstractDeviceFormulation},
)
    PSI.set_device_model!(template.base_template, model)
    for (id, sub_template) in get_sub_templates(template)
        new_model = deepcopy(model)
        PSI.set_subsystem!(new_model, id)
        PSI.set_device_model!(sub_template, new_model)
    end
    return
end

"""
    PSI.set_service_model!(template::MultiProblemTemplate, service_name::String,
                           service_type::Type{<:PSY.Service},
                           formulation::Type{<:PSI.AbstractServiceFormulation})

Create a named service model in the base and every regional template.

Construct separate models with `use_service_name=true`, store them under
`service_name` using the upstream setter, and set each regional model's
subsystem to its key. Return `nothing`.
"""
function PSI.set_service_model!(
    template::MultiProblemTemplate,
    service_name::String,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(
        template.base_template,
        service_name,
        PSI.ServiceModel(service_type, formulation; use_service_name=true),
    )
    for (id, sub_template) in get_sub_templates(template)
        service_model = PSI.ServiceModel(service_type, formulation; use_service_name=true)
        PSI.set_subsystem!(service_model, id)
        PSI.set_service_model!(sub_template, service_name, service_model)
    end
    return
end

"""
    PSI.set_service_model!(template::MultiProblemTemplate,
                           service_type::Type{<:PSY.Service},
                           formulation::Type{<:PSI.AbstractServiceFormulation})

Create default service models in the base and every regional template.

Construct each model independently with the upstream defaults, and set each
regional model's subsystem to its template key. Return `nothing`.
"""
function PSI.set_service_model!(
    template::MultiProblemTemplate,
    service_type::Type{<:PSY.Service},
    formulation::Type{<:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(
        template.base_template,
        PSI.ServiceModel(service_type, formulation),
    )
    for (id, sub_template) in get_sub_templates(template)
        service_model = PSI.ServiceModel(service_type, formulation)
        PSI.set_subsystem!(service_model, id)
        PSI.set_service_model!(sub_template, service_model)
    end
    return
end

"""
    PSI.set_service_model!(template::MultiProblemTemplate, service_name::String,
                           model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation})

Store a named service model in the base and regional deep copies.

Pass `service_name` to each upstream setter. Retain `model` by reference in
the base; before each regional copy, mutate its subsystem to the regional key.
The caller's model therefore retains the last visited subsystem, whose order
is unspecified. Return `nothing`.
"""
function PSI.set_service_model!(
    template::MultiProblemTemplate,
    service_name::String,
    model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(template.base_template, service_name, model)
    for (id, sub_template) in get_sub_templates(template)
        PSI.set_subsystem!(model, id)
        PSI.set_service_model!(sub_template, service_name, deepcopy(model))
    end
    return
end

"""
    PSI.set_service_model!(template::MultiProblemTemplate,
                           model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation})

Store `model` in the base and a regional deep copy under its upstream service key.

Mutate the supplied model's subsystem before making each regional copy.
The base retains that same supplied object, so it and the caller's model
retain the last visited subsystem. Dictionary iteration does not specify
which subsystem is last. Return `nothing`.
"""
function PSI.set_service_model!(
    template::MultiProblemTemplate,
    model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
)
    PSI.set_service_model!(template.base_template, model)
    for (id, sub_template) in get_sub_templates(template)
        PSI.set_subsystem!(model, id)
        PSI.set_service_model!(sub_template, deepcopy(model))
    end
    return
end

"""
    PSI.set_service_model!(template::MultiProblemTemplate,
                           model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
                           subsystem_id::String)

Store `model` in the base and a deep copy in the requested regional template.

When `subsystem_id` matches a regional key, first mutate the supplied model's
subsystem to that key, then copy it into that region. Other regions are left
unchanged. The base retains the supplied object by reference.

An unknown key does not raise an error: only the base entry is set, and the
supplied model's subsystem is unchanged. Return `nothing`.
"""
function PSI.set_service_model!(
    template::MultiProblemTemplate,
    model::PSI.ServiceModel{<:PSY.Service, <:PSI.AbstractServiceFormulation},
    subsystem_id::String,
)
    PSI.set_service_model!(template.base_template, model)
    for (id, sub_template) in get_sub_templates(template)
        if id == subsystem_id
            PSI.set_subsystem!(model, id)
            PSI.set_service_model!(sub_template, deepcopy(model))
        end
    end
    return
end

"""
    finalize_template!(template::MultiProblemTemplate, sys::PSY.System)

Finalize the base and regional templates against `sys` in place.

Use upstream finalization for the base, then apply subsystem-aware finalization
to each regional template. Populate service associations and remove regionally
empty device and branch models without assigning System components. Return
`nothing` and propagate upstream errors.
"""
function finalize_template!(template::MultiProblemTemplate, sys::PSY.System)
    PSI.finalize_template!(template.base_template, sys)
    for (ix, sub_template) in get_sub_templates(template)
        finalize_template!(sub_template, sys, ix)
    end
    return
end

"""
    finalize_template!(template::PSI.ProblemTemplate, sys::PSY.System,
                       subsystem::String)

Finalize one regional template using available components in `subsystem`.

Remove branch and device models with no available regional components and
register retained AC branch types with the network model. Populate aggregated
service models, contributing devices, device/service associations, and outage
metadata through the upstream helpers. Outages must explicitly monitor components
modeled by their regional template. Mutate the template and its contained models,
leave System membership unchanged, and return `nothing`.
"""
function finalize_template!(
    template::PSI.ProblemTemplate,
    sys::PSY.System,
    subsystem::String,
)
    _add_modeled_ac_branches!(template, sys, subsystem)
    _check_for_empty_device_models!(template, sys, subsystem)
    PSI._populate_aggregated_service_model!(template, sys)
    PSI._populate_contributing_devices!(template, sys)
    PSI._add_services_to_device_model!(template)
    PSI._build_device_model_outages!(template, sys)
    PSI._build_service_model_outages!(template, sys)
    return
end

function _check_for_empty_device_models!(
    template::PSI.ProblemTemplate,
    sys::PSY.System,
    subsystem::String,
)
    device_models = PSI.get_device_models(template)
    for (key, device_model) in collect(device_models)
        component_type = PSI.get_component_type(device_model)
        components =
            PSY.get_available_components(component_type, sys; subsystem_name=subsystem)
        if isempty(components)
            pop!(device_models, key)
            @warn "Device model for $component_type is included in the main template but there are no available components of this type in subsystem $subsystem and will be removed from the template"
        end
    end
    return
end

function _add_modeled_ac_branches!(
    template::PSI.ProblemTemplate,
    sys::PSY.System,
    subsystem::String,
)
    network_model = PSI.get_network_model(template)
    branch_models = PSI.get_branch_models(template)
    for (key, v) in collect(branch_models)
        component_type = PSI.get_component_type(v)
        if isempty(
            PSY.get_available_components(component_type, sys; subsystem_name=subsystem),
        )
            pop!(branch_models, key)
            @warn "$component_type is modeled but not in subsystem $subsystem so removed from the template"
        else
            if (component_type <: PSY.ACTransmission)
                push!(network_model.modeled_ac_branch_types, component_type)
            end
        end
    end
    return
end
