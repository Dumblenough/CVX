% GENERALIZED FUNTION APPROXIMATION BY FEATURES

% Fit a function f: R --> R by polynomial features (e.g. a short Taylor
% Series) on a given domain

k = 500; % #of discrete domain points

t1_left = zeros(k,1); %to hold t data
t2_left = zeros(k,1); %to hold t^2 data
t3_left = zeros(k,1); %to hold t^2 data
t4_left = zeros(k,1); %to hold t^2 data
t5_left = zeros(k,1); %to hold t^2 data
t6_left = zeros(k,1); %to hold t^2 data
t7_left = zeros(k,1); %to hold t^2 data
t8_left = zeros(k,1); %to hold t^2 data
t9_left = zeros(k,1); %to hold t^2 data
t10_left = zeros(k,1); %to hold t^2 data
t11_left = zeros(k,1); %to hold t^2 data

t1_right = zeros(k,1); %to hold t data
t2_right = zeros(k,1); %to hold t^2 data
t3_right = zeros(k,1); %to hold t^2 data
t4_right = zeros(k,1); %to hold t^2 data
t5_right = zeros(k,1); %to hold t^2 data
t6_right = zeros(k,1); %to hold t^2 data
t7_right = zeros(k,1); %to hold t^2 data
t8_right = zeros(k,1); %to hold t^2 data
t9_right = zeros(k,1); %to hold t^2 data
t10_right = zeros(k,1); %to hold t^2 data
t11_right = zeros(k,1); %to hold t^2 data

t1_both = zeros(k,1); %to hold t data
t2_both = zeros(k,1); %to hold t^2 data
t3_both = zeros(k,1); %to hold t^2 data
t4_both = zeros(k,1); %to hold t^2 data
t5_both = zeros(k,1); %to hold t^2 data
t6_both = zeros(k,1); %to hold t^2 data
t7_both = zeros(k,1); %to hold t^2 data
t8_both = zeros(k,1); %to hold t^2 data
t9_both = zeros(k,1); %to hold t^2 data
t10_both = zeros(k,1); %to hold t^2 data
t11_both = zeros(k,1); %to hold t^2 data

y_left = zeros(k,1); %to hold y = f(x) data
y_right = zeros(k,1); %to hold y = f(x) data
y_both = zeros(k,1); %to hold y = f(x) data

lower_lim_left = -pi; % set as desired
upper_lim_left = 0;

lower_lim_right = 0; % set as desired
upper_lim_right = pi;

lower_lim_both = -pi; % set as desired
upper_lim_both = pi;

for i=1:k
   t1_left(i) = lower_lim_left + (upper_lim_left-lower_lim_left)*(i-1)/(k-1);% the linspace
   t2_left(i) = t1_left(i)*t1_left(i);
   t3_left(i) = t2_left(i)*t2_left(i);
   t4_left(i) = t2_left(i)*t3_left(i);
   t5_left(i) = t2_left(i)*t4_left(i);
   t6_left(i) = t2_left(i)*t5_left(i);
   t7_left(i) = t2_left(i)*t6_left(i);
   t8_left(i) = t2_left(i)*t7_left(i);
   t9_left(i) = t2_left(i)*t8_left(i);
   t10_left(i) = t2_left(i)*t9_left(i);
   t11_left(i) = t2_left(i)*t10_left(i);
   
   t1_right(i) = lower_lim_right + (upper_lim_right-lower_lim_right)*(i-1)/(k-1);% the linspace
   t2_right(i) = t1_right(i)*t1_right(i);
   t3_right(i) = t2_right(i)*t2_right(i);
   t4_right(i) = t2_right(i)*t3_right(i);
   t5_right(i) = t2_right(i)*t4_right(i);
   t6_right(i) = t2_right(i)*t5_right(i);
   t7_right(i) = t2_right(i)*t6_right(i);
   t8_right(i) = t2_right(i)*t7_right(i);
   t9_right(i) = t2_right(i)*t8_right(i);
   t10_right(i) = t2_right(i)*t9_right(i);
   t11_right(i) = t2_right(i)*t10_right(i);
   
   t1_both(i) = lower_lim_both + (upper_lim_both-lower_lim_both)*(i-1)/(k-1);% the linspace
   t2_both(i) = t1_both(i)*t1_both(i);
   t3_both(i) = t2_both(i)*t2_both(i);
   t4_both(i) = t2_both(i)*t3_both(i);
   t5_both(i) = t2_both(i)*t4_both(i);
   t6_both(i) = t2_both(i)*t5_both(i);
   t7_both(i) = t2_both(i)*t6_both(i);
   t8_both(i) = t2_both(i)*t7_both(i);
   t9_both(i) = t2_both(i)*t8_both(i);
   t10_both(i) = t2_both(i)*t9_both(i);
   t11_both(i) = t2_both(i)*t10_both(i);
   
   % Function to approximate:
   y_left(i) = sin(t1_left(i));
   y_right(i) = sin(t1_right(i));
   y_both(i) = cos(t1_both(i));
end


%test
%figure; plot(y); %good


% Optimization Routine below

%%%%%% LEFT
X_left = [ones(k,1), t1_left, t2_left, t3_left, t4_left]';
Y_left = [y_left]';
m = size(Y_left,1); 
n = size(X_left,1);
cvx_begin
    variable W0_left(m,n)
    minimize norm(Y_left - W0_left*X_left, Inf)
cvx_end
figure; plot(y_left); figure; plot(W0_left*X_left);

%%%%%% RIGHT
X_right = [ones(k,1), t1_right, t2_right, t3_right, t4_right]';
Y_right = [y_right]';
m = size(Y_right,1);
n = size(X_right,1);
cvx_begin
    variable W0_right(m,n)
    minimize norm(Y_right - W0_right*X_right, Inf)
cvx_end
figure; plot(y_right); figure; plot(W0_right*X_right);

%%%%%% BOTH
X_both = [ones(k,1), t1_both, t2_both, t3_both, t4_both]';
Y_both = [y_both]';
m = size(Y_both,1);
n = size(X_both,1);
cvx_begin
    variable W0_both(m,n)
    minimize norm(Y_both - W0_both*X_both, 2)
cvx_end
figure; plot(y_both); figure; plot(W0_both*X_both);