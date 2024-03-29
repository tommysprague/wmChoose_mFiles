 % cat_struct.m
%
% simple utility function that concatenates entries in all compatible
% fields; recursive to also concatenate sub-structs
%
% always vertically concatenates
%
% for string fields, creates a cell array


function s_combined = cat_struct(s1,s2,skip_fields)

% which fields do we not concatenate (will use s1's values)?

% include ability to loop over an arbitrary length of structs to cat, whcih
% means the first time you're cat'ing w/ nothing (replicates pattern of:
% my data = []; for ii = 1:10; mydata = [mydata; rand(5,1)]; end;
if isempty(s1)
    s_combined = s2;
    return;
end

if nargin < 3
    skip_fields = {};
end

fields_to_cat = setdiff(fieldnames(s1),skip_fields);


% initialize s_combined to be s1, then loop over and add elements of s2
s_combined = s1; % (we do this so that skipped fields are still populated)

for ff = 1:length(fields_to_cat)
    
    if isstruct(s1.(fields_to_cat{ff}))
        s_combined.(fields_to_cat{ff}) = cat_struct(s1.(fields_to_cat{ff}),s2.(fields_to_cat{ff}));
    
        
    elseif ischar(s1.(fields_to_cat{ff}))
        
        s_combined.(fields_to_cat{ff}) = {s1.(fields_to_cat{ff});s2.(fields_to_cat{ff})};
        
    else
        
        s_combined.(fields_to_cat{ff}) = vertcat(s1.(fields_to_cat{ff}),s2.(fields_to_cat{ff}));
        
    end
    
    
    
end




return