import React, { useState, useEffect } from "react";
import { MetaDecorator, Overlay, Icon } from "../components";
import Button from '@mui/material/Button'
import { DockerClient } from "../client";
import Container from '@mui/material/Container';
import cn from "classnames";

import Content from "./content";

import { alpha } from '@mui/material/styles';
import Box from '@mui/material/Box';
import Table from '@mui/material/Table';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TableContainer from '@mui/material/TableContainer';
import TableHead from '@mui/material/TableHead';
import TablePagination from '@mui/material/TablePagination';
import TableRow from '@mui/material/TableRow';
import TableSortLabel from '@mui/material/TableSortLabel';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import Paper from '@mui/material/Paper';

import { visuallyHidden } from '@mui/utils';

import {
  DataColumn,
  Status,
  Image as ImageType,
  Container as ContainerType
} from "../interfaces";

const StatusDot:React.FunctionComponent<{status: string}>  = ({status}) => <div className={cn("status-dot", status)}></div>

const Help:React.FunctionComponent<{
  showModal: boolean,
  handleClose: any,
}> = ({showModal, handleClose}) => {
  return (
    <Overlay
      show={showModal}
      onHide={handleClose}
      className={cn("modal")}
    >
      <Content title="Help" path="help" /><Button onClick={handleClose} className="close-button" color={undefined}><Icon icon="close"/></Button>
    </Overlay>
  )
};

function descendingComparator<T>(a: T, b: T, orderBy: keyof T) {
  if (b[orderBy] < a[orderBy]) {
    return -1;
  }
  if (b[orderBy] > a[orderBy]) {
    return 1;
  }
  return 0;
}

type Order = 'asc' | 'desc';

function getComparator<T>(
  order: Order,
  orderBy: keyof T,
): (
  a: T,
  b: T,
) => number {
  return order === 'desc'
    ? (a, b) => descendingComparator<T>(a, b, orderBy)
    : (a, b) => -descendingComparator<T>(a, b, orderBy);
}

function stableSort<T>(array: readonly T[], comparator: (a: T, b: T) => number) {
  const stabilizedThis = array.map((el, index) => [el, index] as [T, number]);
  stabilizedThis.sort((a, b) => {
    const order = comparator(a[0], b[0]);
    if (order !== 0) {
      return order;
    }
    return a[1] - b[1];
  });
  return stabilizedThis.map((el) => el[0]);
}

interface EnhancedTableProps<T> {
  onRequestSort: (event: React.MouseEvent<unknown>, property: keyof T) => void;
  order: Order;
  orderBy: string;
  rowCount: number;
}
function EnhancedTableHead<T>(
  props: EnhancedTableProps<T> & {headCells: DataColumn<T>[]}
) {
  const { order, orderBy, rowCount, headCells, onRequestSort } =
    props;
  const createSortHandler =
    (property: keyof T) => (event: React.MouseEvent<unknown>) => {
      onRequestSort(event, property);
    };

  return (
    <TableHead>
      <TableRow>
        {headCells.map((headCell) => (
          <TableCell
            key={headCell.id as React.Key}
            align={headCell.numeric ? 'right' : 'left'}
            padding={headCell.disablePadding ? 'none' : 'normal'}
            sortDirection={orderBy === headCell.id ? order : false}
          >
            <TableSortLabel
              active={orderBy === headCell.id}
              direction={orderBy === headCell.id ? order : 'asc'}
              onClick={createSortHandler(headCell.id)}
            >
              {headCell.label}
              {orderBy === headCell.id ? (
                <Box component="span" sx={visuallyHidden}>
                  {order === 'desc' ? 'sorted descending' : 'sorted ascending'}
                </Box>
              ) : null}
            </TableSortLabel>
          </TableCell>
        ))}
        <TableCell></TableCell>
      </TableRow>
    </TableHead>
  );
}

function EnhancedTable<T extends object>({data, columns}: {data: T[], columns: DataColumn<T>[]}) {
  const [order, setOrder] = React.useState<Order>('asc');
  const [orderBy, setOrderBy] = React.useState<keyof T>('validated' as keyof T);
  const [page, setPage] = React.useState(0);
  const [dense, setDense] = React.useState(false);
  const [rowsPerPage, setRowsPerPage] = React.useState(5);

  const handleRequestSort = (
    event: React.MouseEvent<unknown>,
    property: keyof T,
  ) => {
    const isAsc = orderBy === property && order === 'asc';
    setOrder(isAsc ? 'desc' : 'asc');
    setOrderBy(property);
  };

  return (
    <Box sx={{ width: '100%' }}>
      <Paper sx={{ width: '100%', mb: 2 }} elevation={1} variant={"elevation"}>
        <TableContainer>
          <Table
            sx={{ minWidth: 750 }}
            aria-labelledby="tableTitle"
            size={dense ? 'small' : 'medium'}
          >
            <EnhancedTableHead<T>
              order={order}
              orderBy={orderBy as string}
              onRequestSort={handleRequestSort}
              rowCount={data.length}
              headCells={columns}
            />
            <TableBody>
              {data.length 
              ? stableSort<T>(data, getComparator<T>(order, orderBy))
                .map((row, index) => {
                  return (
                    <TableRow
                      key={index}
                    > 
                      {columns.map((column, index) => column.id === "validated" ? <TableCell key={String(column.id)}><StatusDot status={String(row[column.id])}/></TableCell> :  <TableCell key={String(column.id)}><>{row[column.id]}</></TableCell>)}
                      <TableCell
                        className="cell-button"
                      >
                        <Button
                          color="inherit"
                          variant="contained"
                          size="small"
                        >Validate</Button>
                      </TableCell>
                    </TableRow>
                  );
                })
              : 
              <TableRow> 
                <TableCell colSpan={columns.length}>
                  <span className="loading">Loading...</span>
                </TableCell>
              </TableRow>}

            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </Box>
  );
}

const Main:React.FunctionComponent<{}> = () => {
  const [containers, setContainers] = useState<Array<ContainerType>>([]);
  const [images, setImages] = useState<Array<ImageType>>([]);
  const [showModal, setShowModal] = useState<boolean>(false);

  // function createData<T>(props: keyof T): T {
  //   return {
  //     name,
  //     calories,
  //     fat,
  //     carbs,
  //     protein,
  //   };
  // }

  const columns: DataColumn<ContainerType>[] = React.useMemo(
    () => [
      {
        label: "",
        id: "validated",
        maxWidth: 30,
        minWidth: 30,
        width: 30,
        numeric: false,
        disablePadding: false
      },
      {
        label: "Container hash",
        id: "containerHash",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 150,
        width: 200,
      },
      {
        label: "Container name",
        id: "containerName",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
      {
        label: "Image hash",
        id: "imageHash",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
      {
        label: "Build provider",
        id: "buildProvider",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
      {
        label: "Gosh network root",
        id: "goshRootAddress",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
    ],
    []
  );

  const columnsImage: Array<DataColumn<ImageType>> = React.useMemo(
    () => [
      {
        label: "",
        id: "validated",
        numeric: false,
        disablePadding: false,
        maxWidth: 30,
        minWidth: 30,
        width: 30,
      },
      {
        label: "Image hash",
        id: "imageHash",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
      {
        label: "Build provider",
        id: "buildProvider",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
      {
        label: "Gosh network root",
        id: "goshRootAddress",
        numeric: false,
        disablePadding: false,
        maxWidth: 400,
        minWidth: 165,
        width: 200,
      },
    ],
    []
  );
  const data = React.useMemo<ContainerType[]>(() => ([{
    validated: "success",
    containerHash: "05deec074512993...",
    containerName: "/exciting_brahrnag...",
    imageHash: "sha256:137444141...",
    buildProvider: "-",
    goshRootAddress: ""
  },{
    validated: "success",
    containerHash: "85b26c7366d42e...",
    containerName: "/blissful_gates",
    imageHash: "sha256:3954a180f...",
    buildProvider: "95c06aa743d1f90...",
    goshRootAddress: ""
  },{
    validated: "error",
    containerHash: "0c9039aa990d70... ",
    containerName: "/docker-beautifu...",
    imageHash: "sha256:b5ec650b2...",
    buildProvider: "84a595396a47a6c...",
    goshRootAddress: ""
  }]), undefined);

  const dataImage = React.useMemo<ImageType[]>(() => ([{
    validated: "success",
    imageHash: "sha256:3954a180f...",
    buildProvider: "95c06aa743d1f90...",
    goshRootAddress: ""
  },{
    validated: "success",
    imageHash: "sha256:137444141...",
    buildProvider: "-",
    goshRootAddress: ""
  }]), undefined);

  

  useEffect(() => {
    DockerClient.getContainers()
    .then((value) => {
      console.log(value);
      setContainers(value || []);
      //do stuff
    });
  }, []);

  useEffect(() => {
    DockerClient.getImages()
    .then((value) => {
      console.log(value);
      setImages(value || []);
      //do stuff
    });
  }, []);

  // const data = React.useMemo<Array<ContainerType>>(() => ([{
  //   validated: "loading",
  //   containerHash: 78165381872341234,
  //   containerName: "nginx-main",
  //   imageHash: 1948731,
  //   buildProvider: "239182",
  // }]), undefined);

  const handleClick = () => {
    DockerClient.getContainers()
    .then((value) => {
      console.log(value);
      setContainers(value || []);
      //do stuff
    });
  }
  const handleClose = () => setShowModal(false);
  const handleShow = () => setShowModal(true);


  return (
    <>
    <MetaDecorator
      title="Gosh Docker Extension"
      description="Git On-chain Source Holder Docker extension for Secure Software Supply BlockChain"
      keywords="docker, gosh, extension, sssb, sssp"
    />
    <div className="button-block">

      <Button
        color="primary"
        size="medium"
        disableElevation
        // icon={<Icon icon={"arrow-up-right"}/>}
        // iconAnimation="right"
        // iconPosition="after"
        onClick={handleShow}
      >Help <></></Button>
      <Button
        disableElevation
        color="primary"
        variant="contained"
        size="medium"
        onClick={handleClick}
      >Update data</Button>
    </div>
    <Container maxWidth={false}>
          <div className="content-container">
            <Typography variant="h6">Containers</Typography>
            <EnhancedTable<ContainerType> data={containers} columns={columns} />
            <Typography variant="h6">Images</Typography>
            <EnhancedTable<ImageType> data={images} columns={columnsImage} />
          </div>

    </Container>
      <Help
        showModal={showModal}
        handleClose={handleClose}
      />
    </>
  );
};


export default Main;
