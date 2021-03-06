% Given a quadratic, 1/2 * x'*P*x + q'*x + r (P > 0)
% Return the SOC format, i.e. ||Bk0*x + dk0||2 <= Bk1*x + dk1
% Source: http://en.wikipedia.org/wiki/Second-order_cone_programming#Example:_Quadratic_constraint
% (and some algebra)
function [Bk0, dk0, bk1, dk1] = QuadraticToSOC(P, q, r)
    %A = chol(0.5*P);
    [L,D] = ldl(0.5*P);
    A = (L*D^0.5)'; % so that A'*A == 0.5*P
    b = q;
    c = r;
    Bk0 = [A; b'/2];
    dk0 = [zeros(size(A,1),1); (c+1)/2];
    bk1 = -b'/2;
    dk1 = (1-c)/2;
end