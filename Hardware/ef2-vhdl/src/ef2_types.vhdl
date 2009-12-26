
package ef2_types is

    -- states for the expansion port bus
    type bus_state_type is 
    (
        BUS_IDLE,
        BUS_WRITE_VALID,
        BUS_WRITE_ENABLE,
        BUS_READ_VALID 
    );

end ef2_types;