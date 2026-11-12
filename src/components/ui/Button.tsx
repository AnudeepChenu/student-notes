
import { ButtonHTMLAttributes } from "react";

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "outline";
}

export default function Button({
  children,
  variant = "primary",
  className = "",
  ...props
}: Props) {
  const styles = {
    primary: "bg-indigo-600 text-white hover:bg-indigo-700",
    secondary: "bg-indigo-50 text-indigo-700 hover:bg-indigo-100",
    outline: "border border-gray-200 bg-white hover:bg-gray-50",
  };

  return (
    <button
      className={`px-5 py-2.5 rounded-xl text-sm font-medium transition ${styles[variant]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}
