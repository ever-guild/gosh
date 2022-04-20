import { useEffect, ReactNode, InputHTMLAttributes } from "react";
import styles from './Flex.module.scss';
import classnames from "classnames/bind";

const cnb = classnames.bind(styles);

export interface FlexProps extends InputHTMLAttributes<HTMLInputElement>{
  grow?: number,
  shrink?: number
}
export interface FlexContainerProps extends InputHTMLAttributes<HTMLInputElement>{
  direction?: string,
  justify?: string,
  align?: string,
}

export const FlexContainer = ({
  direction,
  justify,
  align,
  children,
  ...props
} : FlexContainerProps) => {
  return <>
    <div
      className={cnb("flex-container", direction ? "flex-container-row" : "flex-container-" + direction)}
      style={{
        justifyContent: justify,
        alignItems: align
      }}
      {...props}
    >
      {children}
    </div>
  </>;
};

export const Flex = ({
  grow,
  shrink,
  children,
  ...props
} : FlexProps) => {
  return <>
    <div
      className={cnb("flex")}
      style={{
        flexGrow: grow,
        flexShrink: shrink
      }}
      {...props}
    >
      {children}
    </div>
  </>;
};